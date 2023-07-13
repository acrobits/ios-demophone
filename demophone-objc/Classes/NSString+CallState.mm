/*
 * 
 * NSString+CallState.mm
 * demophone
 * 
 * Created by Jiri Kral on 6/12/11.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import "NSString+CallState.h"
#include "Ali/ali_mac_str_utils.h"

@implementation NSString(CallState)

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
+(NSString *) stringFromCallState:(Call::State::Type) callState
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    return ali::mac::str::to_nsstring(Call::State::toString(callState));
}

@end
