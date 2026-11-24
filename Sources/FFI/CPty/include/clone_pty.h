#ifndef CLONE_PTY_H
#define CLONE_PTY_H

#include <sys/types.h>

// Spawn `path` (argv NULL-terminated) on the slave side of a new PTY sized
// rows x cols. `envp` may be NULL (inherit the current environment). Returns the
// child pid (> 0) and writes the master fd to *out_master, or -1 on error. The
// child execs entirely in C and never returns to Swift (avoids running Swift in
// a post-fork child, which is unsafe).
pid_t clone_pty_spawn(const char *path, char *const argv[], char *const envp[],
                      unsigned short rows, unsigned short cols, int *out_master);

// Resize the pty (TIOCSWINSZ on the master). Returns 0 on success, -1 on error.
int clone_pty_set_winsize(int master_fd, unsigned short rows, unsigned short cols);

#endif
