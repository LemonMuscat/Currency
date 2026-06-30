#include <libgen.h>
#include <fcntl.h>
#include <limits.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <sys/stat.h>
#include <unistd.h>

extern char **environ;

static int copy_file(const char *source, const char *destination) {
    int input = open(source, O_RDONLY);
    if (input < 0) {
        return 1;
    }

    int output = open(destination, O_WRONLY | O_CREAT | O_TRUNC, 0755);
    if (output < 0) {
        close(input);
        return 1;
    }

    char buffer[65536];
    ssize_t readCount;
    while ((readCount = read(input, buffer, sizeof(buffer))) > 0) {
        char *cursor = buffer;
        ssize_t remaining = readCount;
        while (remaining > 0) {
            ssize_t written = write(output, cursor, (size_t)remaining);
            if (written < 0) {
                close(input);
                close(output);
                return 1;
            }
            cursor += written;
            remaining -= written;
        }
    }

    close(input);
    close(output);
    chmod(destination, 0755);
    return readCount < 0 ? 1 : 0;
}

int main(int argc, char **argv) {
    const char *pidPath = "/private/tmp/local.codex.CurrencyPanel.pid";
    FILE *pidFile = fopen(pidPath, "r");
    if (pidFile != NULL) {
        long oldPid = 0;
        if (fscanf(pidFile, "%ld", &oldPid) == 1 && oldPid > 0) {
            kill((pid_t)oldPid, SIGTERM);
            usleep(250000);
        }
        fclose(pidFile);
    }

    char executablePath[PATH_MAX];
    if (realpath(argv[0], executablePath) == NULL) {
        return 1;
    }

    char *macOSDir = dirname(executablePath);
    char runtimePath[PATH_MAX];
    snprintf(runtimePath, sizeof(runtimePath), "%s/CurrencyPanelRuntime", macOSDir);

    char iconPath[PATH_MAX];
    snprintf(iconPath, sizeof(iconPath), "%s/../Resources/AppIcon.icns", macOSDir);

    copy_file(iconPath, "/private/tmp/local.codex.CurrencyPanel.AppIcon.icns");

    char *childArgv[] = { runtimePath, NULL };
    pid_t child = 0;
    if (posix_spawn(&child, runtimePath, NULL, NULL, childArgv, environ) != 0) {
        return 1;
    }

    pidFile = fopen(pidPath, "w");
    if (pidFile != NULL) {
        fprintf(pidFile, "%d\n", child);
        fclose(pidFile);
    }

    return 0;
}
