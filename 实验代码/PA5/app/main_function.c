#include "myos.h"

int t=0;
int main(void)
{   if(fork()==0)
  {
    t=1;
    while(1)
    {
      write("Ping!",5);
      sleep(t);
    }
  }else{
    t=2;
    while(1)                                                
    {
      write("Pong!",5);
      sleep(t);                
    }
  }
}