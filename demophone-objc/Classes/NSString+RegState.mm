/*
 * 
 * NSString+RegState.mm
 * demophone
 * 
 * Created by Jiri Kral on 4/27/12.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import "NSString+RegState.h"
#include "Ali/ali_mac_str_utils.h"

@implementation NSString(RegState)

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
+(NSString *) stringFromRegState:(Registrator::State::Type) regState
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    return ali::mac::str::to_nsstring(Registrator::State::toString(regState));
}

@end
