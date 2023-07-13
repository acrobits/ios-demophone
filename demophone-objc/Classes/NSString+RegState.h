/*
 * 
 * NSString+RegState.h
 * demophone
 * 
 * Created by Jiri Kral on 4/27/12.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import <Foundation/Foundation.h>
#import "Softphone/Softphone.h"

/**
 @brief Transforms the @ref Registrator::State::Type into textual form
 */

@interface NSString(RegState)

+(NSString *) stringFromRegState:(Registrator::State::Type) regState;

@end
