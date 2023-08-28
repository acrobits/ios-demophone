#import "TargetPickerViewController.h"
#import "demophoneAppDelegate.h"

// ******************************************************************
@interface TargetPickerViewController () <UITableViewDelegate, UITableViewDataSource>
// ******************************************************************
{
    ali::array<Softphone::EventHistory::CallEvent::Pointer> _attendedTransferTargets;
}

@property (nonatomic, weak) IBOutlet UITableView *callsTableView;

@end

// ******************************************************************
@implementation TargetPickerViewController
// ******************************************************************

// ******************************************************************
- (void)viewDidLoad
// ******************************************************************
{
    [super viewDidLoad];
}

// ******************************************************************
- (void)setAttendedTransferTargets:(ali::array<Softphone::EventHistory::CallEvent::Pointer> const&)targets
// ******************************************************************
{
    _attendedTransferTargets = targets;
}

// ******************************************************************
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section
// ******************************************************************
{
    return _attendedTransferTargets.size();
}

// ******************************************************************
- (UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
// ******************************************************************
{
    static NSString *MyIdentifier = @"CallCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:MyIdentifier];
    }
    
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    
    Softphone::EventHistory::CallEvent::Pointer call = _attendedTransferTargets[static_cast<int>(indexPath.row)];
    const ali::string displayName = call->getRemoteUser().getDisplayName();
    cell.textLabel.text = [NSString stringWithFormat:@"Call with %s",displayName.c_str()];
    cell.contentView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
    
    return cell;
}

// ******************************************************************
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
// ******************************************************************
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (_pickerDelgate && [_pickerDelgate respondsToSelector:@selector(pickerViewController:didSelectTarget:)])
    {
        Softphone::EventHistory::CallEvent::Pointer call = _attendedTransferTargets[static_cast<int>(indexPath.row)];
        [_pickerDelgate pickerViewController:self didSelectTarget:call];
    }
}

// ******************************************************************
-(IBAction)onClose:(id)sender
// ******************************************************************
{
    if (_pickerDelgate && [_pickerDelgate respondsToSelector:@selector(pickerViewControllerDidCancel:)])
    {
        [_pickerDelgate pickerViewControllerDidCancel:self];
    }
}

@end
