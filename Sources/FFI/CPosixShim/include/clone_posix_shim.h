#ifndef CLONE_POSIX_SHIM_H
#define CLONE_POSIX_SHIM_H

#include <stddef.h>
#include <stdint.h>

// --- SCM_RIGHTS: send/receive file descriptors over Unix sockets ---

/// Send data with an ancillary file descriptor over a Unix domain socket.
int clone_sendmsg_fd(int sock, const void *data, size_t len, int fd);

/// Receive data with an optional ancillary file descriptor.
/// Writes the received fd to *out_fd (-1 if no fd was attached).
int clone_recvmsg_fd(int sock, void *buf, size_t len, int *out_fd);

// --- macOS: Mach port transfer via bootstrap server ---

#ifdef __APPLE__

/// Register a Mach receive port with the bootstrap server under `name`.
/// Returns 0 on success, -1 on failure. The receive port is written to *out_recv_port.
int clone_mach_register_port(const char *name, uint32_t *out_recv_port);

/// Look up a Mach send port by name from the bootstrap server.
/// Returns 0 on success, -1 on failure.
int clone_mach_lookup_port(const char *name, uint32_t *out_send_port);

/// Send a Mach port right to a destination port (via mach_msg).
/// Used to transfer IOSurface Mach ports from app to compositor.
int clone_mach_send_port(uint32_t dest_port, uint32_t port_to_send);

/// Receive a Mach port right from a receive port (via mach_msg).
/// Blocks until a message arrives. The received port is written to *out_port.
int clone_mach_recv_port(uint32_t recv_port, uint32_t *out_port);

/// Import an IOSurface from a Mach port and return its global ID.
/// Returns 0 on failure. The imported IOSurface stays alive in this process.
uint32_t clone_import_iosurface_port(uint32_t mach_port);

#endif

#endif
