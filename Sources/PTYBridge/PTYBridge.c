#include "PTYBridge.h"
#include <util.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <libproc.h>

extern char **environ;

pid_t lilim_pty_spawn(const char *shell, const char *directory, unsigned short rows,
                     unsigned short columns, int *master) {
    size_t count = 0;
    while (environ[count]) count++;
    char **environment = calloc(count + 4, sizeof(char *));
    if (!environment) return -1;
    size_t index = 0;
    for (size_t i = 0; i < count; i++) {
        if (strncmp(environ[i], "TERM=", 5) && strncmp(environ[i], "COLORTERM=", 10)
            && strncmp(environ[i], "TERM_PROGRAM=", 13)) environment[index++] = environ[i];
    }
    environment[index++] = "TERM=xterm-256color";
    environment[index++] = "COLORTERM=truecolor";
    environment[index++] = "TERM_PROGRAM=Lilim";
    struct winsize size = { .ws_row = rows, .ws_col = columns };
    pid_t child = forkpty(master, NULL, NULL, &size);
    if (child == 0) {
        // All allocation is done before fork. The child only calls async-signal-safe APIs.
        if (chdir(directory) != 0) _exit(126);
        char *const arguments[] = {(char *)shell, "-l", "-i", NULL};
        execve(shell, arguments, environment);
        _exit(127);
    }
    free(environment);
    return child;
}

int lilim_pty_resize(int master, unsigned short rows, unsigned short columns) {
    struct winsize size = { .ws_row = rows, .ws_col = columns };
    return ioctl(master, TIOCSWINSZ, &size);
}

int lilim_pty_directory(pid_t child, char *buffer, int capacity) {
    struct proc_vnodepathinfo info;
    int result = proc_pidinfo(child, PROC_PIDVNODEPATHINFO, 0, &info, sizeof(info));
    if (result != sizeof(info) || capacity <= 0) return 0;
    strlcpy(buffer, info.pvi_cdir.vip_path, (size_t)capacity);
    return 1;
}
