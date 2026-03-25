#ifndef pty_helpers_h
#define pty_helpers_h

#include <sys/types.h>

pid_t pty_fork(void);
int pty_wifexited(int status);
int pty_wexitstatus(int status);
void pty_install_sigchld_handler(void);

#endif /* pty_helpers_h */
