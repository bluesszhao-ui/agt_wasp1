// Remote-bitbang simulation harness for the wasp1 SoC top.
//
// The harness exposes the top-level JTAG pins through the simple remote
// bitbang socket protocol used by OpenOCD's `remote_bitbang` adapter. It keeps
// hclk_i running while socket commands are processed so JTAG DMI requests can
// cross into the SoC debug clock domain.

#include "Vwasp1.h"
#include "verilated.h"

#include <arpa/inet.h>
#include <cerrno>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

static vluint64_t g_time_ns = 0;
static bool g_stop_requested = false;

double sc_time_stamp() { return static_cast<double>(g_time_ns); }

static void handle_signal(int) { g_stop_requested = true; }

static bool has_arg(int argc, char **argv, const char *name) {
  for (int i = 1; i < argc; ++i) {
    if (std::strcmp(argv[i], name) == 0) {
      return true;
    }
  }
  return false;
}

static int parse_plusarg_int(int argc, char **argv, const char *prefix, int default_value) {
  const size_t prefix_len = std::strlen(prefix);
  for (int i = 1; i < argc; ++i) {
    if (std::strncmp(argv[i], prefix, prefix_len) == 0) {
      return std::atoi(argv[i] + prefix_len);
    }
  }
  return default_value;
}

static void advance_time(Vwasp1 *top, int ns) {
  for (int i = 0; i < ns && !Verilated::gotFinish(); ++i) {
    ++g_time_ns;
    if ((g_time_ns % 5) == 0) {
      top->hclk_i = !top->hclk_i;
    }
    top->eval();
  }
}

static void drive_default_inputs(Vwasp1 *top) {
  top->hclk_i = 0;
  top->hresetn_i = 0;
  top->uart_rx_i = 1;
  top->i2c_scl_i = 1;
  top->i2c_sda_i = 1;
  top->gpio_in_i = 0xA5A55A5Au;
  top->jtag_tck_i = 0;
  top->jtag_trst_ni = 0;
  top->jtag_tms_i = 1;
  top->jtag_tdi_i = 0;
  top->eval();
}

static void apply_reset(Vwasp1 *top) {
  top->hresetn_i = 0;
  top->jtag_trst_ni = 0;
  top->jtag_tms_i = 1;
  top->jtag_tdi_i = 0;
  top->jtag_tck_i = 0;
  advance_time(top, 40);
  top->hresetn_i = 1;
  top->jtag_trst_ni = 1;
  advance_time(top, 20);
}

static int open_listen_socket(int port) {
  int listen_fd = ::socket(AF_INET, SOCK_STREAM, 0);
  if (listen_fd < 0) {
    std::perror("socket");
    return -1;
  }

  int enable = 1;
  if (::setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(enable)) < 0) {
    std::perror("setsockopt");
    ::close(listen_fd);
    return -1;
  }

  sockaddr_in addr {};
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr.sin_port = htons(static_cast<uint16_t>(port));

  if (::bind(listen_fd, reinterpret_cast<sockaddr *>(&addr), sizeof(addr)) < 0) {
    std::perror("bind");
    ::close(listen_fd);
    return -1;
  }

  if (::listen(listen_fd, 1) < 0) {
    std::perror("listen");
    ::close(listen_fd);
    return -1;
  }

  return listen_fd;
}

static bool send_tdo(int client_fd, Vwasp1 *top) {
  const char value = top->jtag_tdo_o ? '1' : '0';
  return ::send(client_fd, &value, 1, 0) == 1;
}

static void process_client(Vwasp1 *top, int client_fd) {
  while (!g_stop_requested && !Verilated::gotFinish()) {
    char cmd = 0;
    const ssize_t got = ::recv(client_fd, &cmd, 1, 0);
    if (got == 0) {
      break;
    }
    if (got < 0) {
      if (errno == EINTR) {
        continue;
      }
      std::perror("recv");
      break;
    }

    if (cmd >= '0' && cmd <= '7') {
      const int bits = cmd - '0';
      top->jtag_tdi_i = (bits & 0x1) != 0;
      top->jtag_tms_i = (bits & 0x2) != 0;
      top->jtag_tck_i = (bits & 0x4) != 0;
      advance_time(top, 1);
    } else if (cmd == 'R') {
      if (!send_tdo(client_fd, top)) {
        break;
      }
      advance_time(top, 1);
    } else if (cmd >= 'r' && cmd <= 'u') {
      const int bits = cmd - 'r';
      const bool srst = (bits & 0x1) != 0;
      const bool trst = (bits & 0x2) != 0;
      top->hresetn_i = srst ? 0 : 1;
      top->jtag_trst_ni = trst ? 0 : 1;
      advance_time(top, 2);
    } else if (cmd == 'Q') {
      break;
    } else if (cmd == 'B' || cmd == 'b') {
      // OpenOCD may use blink hints. They are intentionally ignored.
      advance_time(top, 1);
    } else {
      // Unknown adapter hints are ignored to keep the harness tolerant of
      // OpenOCD versions that add non-essential commands.
      advance_time(top, 1);
    }
  }
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  std::signal(SIGINT, handle_signal);
  std::signal(SIGTERM, handle_signal);

  const int port = parse_plusarg_int(argc, argv, "+rbb-port=", 9824);
  const bool keepalive = has_arg(argc, argv, "+rbb-keepalive");
  const int listen_fd = open_listen_socket(port);
  if (listen_fd < 0) {
    return 1;
  }

  Vwasp1 *top = new Vwasp1;
  drive_default_inputs(top);
  apply_reset(top);

  std::printf("wasp1 remote_bitbang listening on 127.0.0.1:%d\n", port);
  std::fflush(stdout);

  while (!g_stop_requested && !Verilated::gotFinish()) {
    sockaddr_in client_addr {};
    socklen_t client_len = sizeof(client_addr);
    const int client_fd = ::accept(
        listen_fd, reinterpret_cast<sockaddr *>(&client_addr), &client_len);
    if (client_fd < 0) {
      if (errno == EINTR) {
        continue;
      }
      std::perror("accept");
      break;
    }

    process_client(top, client_fd);
    ::close(client_fd);
    if (!keepalive) {
      break;
    }
  }

  top->final();
  delete top;
  ::close(listen_fd);
  return 0;
}
