// Doppel launcher: starts the copied ChatGPT executable next to it as an isolated
// instance, with its own Chromium profile and its own Codex home.
//
// Data lives in ~/Library/Application Support/Doppel and ~/.codex-doppel. Installs made
// before the rename keep using their existing folders, so nobody is signed out.
#include <CoreServices/CoreServices.h>
#include <libgen.h>
#include <mach-o/dyld.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// ChatGPT claims the codex:// link scheme every time it starts. The copy would steal
// those links from the original app, so a short-lived helper hands the scheme back.
static int restore_link_handler(void) {
    const int delays[] = {6, 10, 20};
    for (int i = 0; i < 3; i++) {
        sleep(delays[i]);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        LSSetDefaultHandlerForURLScheme(CFSTR("codex"), CFSTR("com.openai.codex"));
#pragma clang diagnostic pop
    }
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc == 2 && strcmp(argv[1], "--doppel-restore-links") == 0) return restore_link_handler();
    char self[4096], resolved[4096];
    uint32_t size = sizeof(self);
    if (_NSGetExecutablePath(self, &size) != 0 || !realpath(self, resolved)) return 1;

    const char *home = getenv("HOME");
    if (!home || !*home) { struct passwd *pw = getpwuid(getuid()); home = pw ? pw->pw_dir : NULL; }
    if (!home) return 1;

    char real[4096], userData[4096], codexHome[4096], flag[4200];
    snprintf(real, sizeof(real), "%s/ChatGPT", dirname(resolved));
    struct stat st;
    snprintf(userData, sizeof(userData), "%s/Library/Application Support/DuplicateGPT", home);
    if (stat(userData, &st) != 0) snprintf(userData, sizeof(userData), "%s/Library/Application Support/Doppel", home);
    snprintf(codexHome, sizeof(codexHome), "%s/.codex-duplicategpt", home);
    if (stat(codexHome, &st) != 0) snprintf(codexHome, sizeof(codexHome), "%s/.codex-doppel", home);
    snprintf(flag, sizeof(flag), "--user-data-dir=%s", userData);
    setenv("CODEX_ELECTRON_USER_DATA_PATH", userData, 1);
    setenv("CODEX_HOME", codexHome, 1);

    if (fork() == 0) {
        setsid();
        execl(resolved, resolved, "--doppel-restore-links", (char *)NULL);
        _exit(0);
    }

    char **args = calloc((size_t)argc + 2, sizeof(char *));
    args[0] = real;
    args[1] = flag;
    for (int i = 1; i < argc; i++) args[i + 1] = argv[i];
    execv(real, args);
    perror("Doppel: could not start ChatGPT");
    return 1;
}
