#include <stdio.h>
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>

void enable_raw_mode()
{
    struct termios term;
    tcgetattr(0, &term);
    term.c_lflag &= ~(ICANON | ECHO); // Disable echo as well
    tcsetattr(0, TCSANOW, &term);
}

void disable_raw_mode()
{
    struct termios term;
    tcgetattr(0, &term);
    term.c_lflag |= ICANON | ECHO;
    tcsetattr(0, TCSANOW, &term);
}

char getch(){
    char buf=0;
    fflush(stdout);
    if(read(0,&buf,1)<0)
        perror("read()");
    return buf;
}

int kbhit()
{
    int byteswaiting;
    ioctl(0, FIONREAD, &byteswaiting);
    return byteswaiting > 0;
}
