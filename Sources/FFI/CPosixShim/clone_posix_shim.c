#include "include/clone_posix_shim.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>

// --- sendmsg/recvmsg with SCM_RIGHTS (cross-platform) ---

int clone_sendmsg_fd(int sock, const void *data, size_t len, int fd) {
    struct iovec iov = {
        .iov_base = (void *)data,
        .iov_len = len
    };

    union {
        struct cmsghdr hdr;
        char buf[CMSG_SPACE(sizeof(int))];
    } cmsg_buf;
    memset(&cmsg_buf, 0, sizeof(cmsg_buf));

    struct msghdr msg = {
        .msg_iov = &iov,
        .msg_iovlen = 1,
        .msg_control = cmsg_buf.buf,
        .msg_controllen = sizeof(cmsg_buf.buf)
    };

    struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    cmsg->cmsg_len = CMSG_LEN(sizeof(int));
    memcpy(CMSG_DATA(cmsg), &fd, sizeof(int));

    return (int)sendmsg(sock, &msg, 0);
}

int clone_recvmsg_fd(int sock, void *buf, size_t len, int *out_fd) {
    *out_fd = -1;

    struct iovec iov = {
        .iov_base = buf,
        .iov_len = len
    };

    union {
        struct cmsghdr hdr;
        char buf[CMSG_SPACE(sizeof(int))];
    } cmsg_buf;
    memset(&cmsg_buf, 0, sizeof(cmsg_buf));

    struct msghdr msg = {
        .msg_iov = &iov,
        .msg_iovlen = 1,
        .msg_control = cmsg_buf.buf,
        .msg_controllen = sizeof(cmsg_buf.buf)
    };

    int n = (int)recvmsg(sock, &msg, 0);
    if (n <= 0) return n;

    struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
    if (cmsg != NULL &&
        cmsg->cmsg_level == SOL_SOCKET &&
        cmsg->cmsg_type == SCM_RIGHTS &&
        cmsg->cmsg_len == CMSG_LEN(sizeof(int))) {
        memcpy(out_fd, CMSG_DATA(cmsg), sizeof(int));
    }

    return n;
}

// --- macOS: Mach port transfer via bootstrap server ---

#ifdef __APPLE__
#include <mach/mach.h>
#include <mach/mach_port.h>
#include <mach/message.h>
#include <servers/bootstrap.h>

// Simple Mach message carrying one port right
typedef struct {
    mach_msg_header_t header;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t port_descriptor;
} clone_mach_port_msg_t;

int clone_mach_register_port(const char *name, uint32_t *out_recv_port) {
    mach_port_t recv_port;
    kern_return_t kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &recv_port);
    if (kr != KERN_SUCCESS) return -1;

    // Add send right so bootstrap can hold one
    kr = mach_port_insert_right(mach_task_self(), recv_port, recv_port, MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        mach_port_deallocate(mach_task_self(), recv_port);
        return -1;
    }

    kr = bootstrap_register(bootstrap_port, (char *)name, recv_port);
    if (kr != KERN_SUCCESS) {
        mach_port_deallocate(mach_task_self(), recv_port);
        return -1;
    }

    *out_recv_port = (uint32_t)recv_port;
    return 0;
}

int clone_mach_lookup_port(const char *name, uint32_t *out_send_port) {
    mach_port_t send_port;
    kern_return_t kr = bootstrap_look_up(bootstrap_port, (char *)name, &send_port);
    if (kr != KERN_SUCCESS) return -1;
    *out_send_port = (uint32_t)send_port;
    return 0;
}

int clone_mach_send_port(uint32_t dest_port, uint32_t port_to_send) {
    clone_mach_port_msg_t msg;
    memset(&msg, 0, sizeof(msg));

    msg.header.msgh_bits = MACH_MSGH_BITS_COMPLEX | MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
    msg.header.msgh_size = sizeof(msg);
    msg.header.msgh_remote_port = (mach_port_t)dest_port;
    msg.header.msgh_local_port = MACH_PORT_NULL;

    msg.body.msgh_descriptor_count = 1;
    msg.port_descriptor.name = (mach_port_t)port_to_send;
    msg.port_descriptor.disposition = MACH_MSG_TYPE_COPY_SEND;
    msg.port_descriptor.type = MACH_MSG_PORT_DESCRIPTOR;

    kern_return_t kr = mach_msg(
        &msg.header,
        MACH_SEND_MSG,
        sizeof(msg),
        0,
        MACH_PORT_NULL,
        MACH_MSG_TIMEOUT_NONE,
        MACH_PORT_NULL
    );
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[clone_mach_send_port] mach_msg send failed: %s (%d)\n", mach_error_string(kr), kr);
        return -1;
    }
    return 0;
}

int clone_mach_recv_port(uint32_t recv_port, uint32_t *out_port) {
    // Use a larger buffer to handle any message format
    struct {
        mach_msg_header_t header;
        mach_msg_body_t body;
        mach_msg_port_descriptor_t port_descriptor;
        mach_msg_trailer_t trailer;
    } msg;
    memset(&msg, 0, sizeof(msg));

    kern_return_t kr = mach_msg(
        &msg.header,
        MACH_RCV_MSG,
        0,
        sizeof(msg),
        (mach_port_t)recv_port,
        MACH_MSG_TIMEOUT_NONE,
        MACH_PORT_NULL
    );
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[clone_mach_recv_port] mach_msg failed: %s (%d)\n", mach_error_string(kr), kr);
        return -1;
    }

    if (!(msg.header.msgh_bits & MACH_MSGH_BITS_COMPLEX) || msg.body.msgh_descriptor_count < 1) {
        fprintf(stderr, "[clone_mach_recv_port] message not complex or no descriptors\n");
        return -1;
    }

    *out_port = (uint32_t)msg.port_descriptor.name;
    return 0;
}

#endif
