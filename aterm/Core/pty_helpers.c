#include "pty_helpers.h"
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>

pid_t pty_fork(void) {
    return fork();
}

int pty_wifexited(int status) {
    return WIFEXITED(status);
}

int pty_wexitstatus(int status) {
    return WEXITSTATUS(status);
}

static void sigchld_handler(int sig) {
    (void)sig;
    // Reap all terminated children
    while (waitpid(-1, NULL, WNOHANG) > 0) {}
}

void pty_install_sigchld_handler(void) {
    struct sigaction sa;
    sa.sa_handler = sigchld_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART | SA_NOCLDSTOP;
    sigaction(SIGCHLD, &sa, NULL);
}
