#include "main.h"

#include <iostream>
#include <thread>

void
hello()
{
    std::cout << "Hello World!\n";
}

int
main(int argc, char** argv)
{
    std::thread t{hello};
    t.join();

    return 0;
}
