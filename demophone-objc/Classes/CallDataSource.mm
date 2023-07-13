/*
 * 
 * CallDataSource.mm
 * demophone
 * 
 * Created by Jiri Kral on 6/12/11.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import "CallDataSource.h"
#import "demophoneAppDelegate.h"
#include "NSString+CallState.h"
#include "Ali/ali_mac_str_utils.h"

@implementation Entry

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(id) initWithGroup:(ali::string const&) groupId
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    if(self = [super init])
    {
        self.group = ali::mac::str::to_nsstring(groupId);
    }
    
    return self;
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(id) initWithCall:(Softphone::EventHistory::CallEvent::Pointer) call
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    if(self = [super init])
    {
        self.group = nil;
        self.call = call;
    }
    
    return self;
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(BOOL) isGroup
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    return self.group != nil;
}

@end


@implementation CallDataSource

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) updateEntries
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	Softphone::Instance * inst = [demophoneAppDelegate theApp].softphone;

    NSMutableArray * entries = [[NSMutableArray alloc] init];
    ali::array_set<ali::string> groups = inst->calls()->conferences()->list();
    
    for(auto groupId : groups)
    {
        Entry * e = [[Entry alloc] initWithGroup:groupId];
        [entries addObject:e];
        
        ali::array_set<Softphone::EventHistory::CallEvent::Pointer> calls = inst->calls()->conferences()->getCalls(groupId);
        
        for(auto call: calls)
        {
            Entry * e = [[Entry alloc] initWithCall:call];
            [entries addObject:e];
        }
    }
    
    _entries = entries;
}


//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	return 1;
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	return [_entries count];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	static NSString *MyIdentifier = @"CallCell";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil)
    {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:MyIdentifier];
	}
    
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.backgroundColor = [UIColor clearColor];

	Softphone::Instance * inst = [demophoneAppDelegate theApp].softphone;

    Entry * entry = [_entries objectAtIndex:indexPath.row];
    ali_assert(entry != nil);
    
    if(entry.isGroup)
    {
        const ali::string groupId = ali::mac::str::from_nsstring(entry.group);
        bool const active = (inst->calls()->conferences()->getActive() == groupId);
        
        cell.textLabel.text = [NSString stringWithFormat:@"Group (%d calls)",inst->calls()->conferences()->getSize(groupId)];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%s",active?"active":""];
        
        cell.contentView.backgroundColor = active?
        [UIColor colorWithRed:0.0f green:1.0f blue:0.0 alpha:0.5]:
        [UIColor colorWithRed:0.9f green:0.9f blue:0.9 alpha:0.5];
    }else
    {
        const ali::string displayName = entry.call->getRemoteUser().getDisplayName();
        Call::State::Type callState = inst->calls()->getState(entry.call);
        Call::HoldStates callHoldState = inst->calls()->isHeld(entry.call);

        cell.textLabel.text = [NSString stringWithFormat:@"Call with %s",displayName.c_str()];
        cell.detailTextLabel.text = [[NSString stringFromCallState:callState] stringByAppendingFormat:@", %@",(callHoldState.local == Call::HoldState::Active)?@"active":@"on hold"];

        cell.contentView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
    }

	return cell;
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(Entry *) entryForIndexPath:(NSIndexPath *)path
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    return [_entries objectAtIndex:path.row];
}

@end
