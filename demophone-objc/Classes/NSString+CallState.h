/*
 * 
 * NSString+CallState.h
 * demophone
 * 
 * Created by Jiri Kral on 6/12/11.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import <Foundation/Foundation.h>
#import "Softphone/Softphone.h"

/**
 @brief Transforms the @ref Call::State::Type into textual form
 */

@interface NSString(CallState)

+(NSString *) stringFromCallState:(Call::State::Type) callState;

@end
