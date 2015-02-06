

#include <sys/cdefs.h>

struct builtincmd {
      const char *name;
      int (*builtin)(int, char **);
};

extern const struct builtincmd builtincmd[];
extern const struct builtincmd splbltincmd[];


int bltincmd(int, char **);
int bgcmd(int, char **);
int breakcmd(int, char **);
int cdcmd(int, char **);
int dotcmd(int, char **);
int echocmd(int, char **);
int evalcmd(int, char **);
int execcmd(int, char **);
int exitcmd(int, char **);
int expcmd(int, char **);
int exportcmd(int, char **);
int falsecmd(int, char **);
#if WITH_HISTORY
int histcmd(int, char **);
int inputrc(int, char **);
#endif
int fgcmd(int, char **);
int getoptscmd(int, char **);
int hashcmd(int, char **);
int jobidcmd(int, char **);
int jobscmd(int, char **);
int localcmd(int, char **);
#ifndef SMALL
#endif
int pwdcmd(int, char **);
int readcmd(int, char **);
int returncmd(int, char **);
int setcmd(int, char **);
int setvarcmd(int, char **);
int shiftcmd(int, char **);
int timescmd(int, char **);
int trapcmd(int, char **);
int truecmd(int, char **);
int typecmd(int, char **);
int umaskcmd(int, char **);
int unaliascmd(int, char **);
int unsetcmd(int, char **);
int waitcmd(int, char **);
int aliascmd(int, char **);
int ulimitcmd(int, char **);
int wordexpcmd(int, char **);
