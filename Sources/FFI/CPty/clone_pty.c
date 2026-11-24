#include "include/clone_pty.h"

#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

// forkpty lives in <pty.h> (+ libutil) on Linux, <util.h> on macOS/BSD.
#if defined(__linux__)
#include <pty.h>
#else
#include <util.h>
#endif

pid_t clone_pty_spawn(const char *path, char *const argv[], char *const envp[],
                      unsigned short rows, unsigned short cols, int *out_master) {
    struct winsize ws;
    ws.ws_row = rows;
    ws.ws_col = cols;
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;

    int master = -1;
    pid_t pid = forkpty(&master, (char *)0, (struct termios *)0, &ws);
    if (pid < 0) {
        return -1;
    }
    if (pid == 0) {
        // Child: the pty slave is already stdin/stdout/stderr + controlling tty.
        if (envp != (char *const *)0) {
            execve(path, argv, envp);
        } else {
            execvp(path, argv);
        }
        _exit(127); // exec failed
    }

    if (out_master) {
        *out_master = master;
    }
    return pid;
}

int clone_pty_set_winsize(int master_fd, unsigned short rows, unsigned short cols) {
    struct winsize ws;
    ws.ws_row = rows;
    ws.ws_col = cols;
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;
    return ioctl(master_fd, TIOCSWINSZ, &ws);
}
