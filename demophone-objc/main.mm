/*
 * 
 * main.m
 * demophone
 * 
 * Created by jiri on 3/28/10.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import <UIKit/UIKit.h>

#import "demophoneAppDelegate.h"
#include <signal.h>
#include "ali/ali_exception.h"

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
void blockSignals()
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    sigset_t mask;
    sigemptyset(&mask);
    sigaddset(&mask, SIGPIPE);
    
    sigprocmask(SIG_BLOCK, &mask, 0);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
int main(int argc, char *argv[])
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	blockSignals();
	
    @autoreleasepool {
        int retVal;
        try {
           retVal = UIApplicationMain(argc, argv, nil, NSStringFromClass([demophoneAppDelegate class]));
        } catch (ali::general_exception e)
        {
            NSLog(@"Exception caught");
        }
        return retVal;
    }
}
