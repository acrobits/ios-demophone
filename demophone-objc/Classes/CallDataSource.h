/*
 * 
 * CallDataSource.h
 * demophone
 * 
 * Created by Jiri Kral on 6/12/11.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#pragma once

#import <Foundation/Foundation.h>
#include "ali/ali_string.h"
#include "Softphone/Softphone.h"

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
@interface Entry : NSObject
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    Softphone::EventHistory::CallEvent::Pointer _callEvent;
}

@property(nonatomic,strong) NSString * group;
@property(nonatomic,assign) Softphone::EventHistory::CallEvent::Pointer call;
@property(nonatomic,readonly,getter=isGroup) BOOL isGroup;

-(id) initWithGroup:(ali::string const&) groupId;
-(id) initWithCall:(Softphone::EventHistory::CallEvent::Pointer) call;

@end

/**
 @class CallDataSource
 @brief Implements UITableViewDataSource for tableview shown in @ref CallViewController with existing calls and
 call groups taken from libsoftphone. 
 */

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
@interface CallDataSource : NSObject<UITableViewDataSource>
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    NSArray * _entries;
}

-(void) updateEntries;
-(Entry *) entryForIndexPath:(NSIndexPath *)path;
@end
