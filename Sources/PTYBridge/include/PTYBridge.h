#ifndef LILIM_PTY_BRIDGE_H
#define LILIM_PTY_BRIDGE_H
#include <sys/types.h>
pid_t lilim_pty_spawn(const char *shell, const char *directory, unsigned short rows,
                     unsigned short columns, int *master);
int lilim_pty_resize(int master, unsigned short rows, unsigned short columns);
int lilim_pty_directory(pid_t child, char *buffer, int capacity);
#endif
