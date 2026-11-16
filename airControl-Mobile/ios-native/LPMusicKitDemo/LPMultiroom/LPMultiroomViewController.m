//
//  LPMultiroomViewController.m
//  LPVBSKitDemo
//
//  Created by sunyu on 2020/3/23.
//  Copyright © 2020 sunyu. All rights reserved.
//

#import "LPMultiroomViewController.h"
#import <LPMusicKit/LPMultiroomManager.h>

@interface LPMultiroomViewController ()

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *deviceArray;
@property (nonatomic, copy) NSString *masterID;

@end

@implementation LPMultiroomViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    LPDeviceManager *manager = [LPDeviceManager sharedInstance];
    LPDevice *selected = [manager deviceForID:self.uuid];
    LPDevice *master = selected;
    if (selected.deviceStatus.roomState == LP_ROOM_SLAVE) {
        master = [manager getMasterDeviceWithSlaveDevice:selected];
        if (!master && selected.deviceStatus.masterID.length)
            master = [manager deviceForID:selected.deviceStatus.masterID];
    }
    self.masterID = master.deviceStatus.UUID;
    self.title = master.deviceStatus.friendlyName.length ?
        [@"Мультирум · " stringByAppendingString:master.deviceStatus.friendlyName] : @"Мультирум";
    
    UIButton *doneButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, 19)];
    doneButton.titleLabel.font = [UIFont systemFontOfSize:17];
    doneButton.userInteractionEnabled = YES;
    [doneButton setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    [doneButton setTitle:@"Done" forState:UIControlStateNormal];
    [doneButton addTarget:self action:@selector(doneButtonClick) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:doneButton];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    self.deviceArray = [NSMutableArray array];
    NSArray *slaveIDs = self.masterID.length ? [[manager slaveDeviceArray:self.masterID] valueForKeyPath:@"deviceStatus.UUID"] : @[];
    NSArray *allDeviceArray = [[LPDeviceManager sharedInstance] deviceArray];
    for (LPDevice *device in allDeviceArray) {
        if ([device.deviceStatus.UUID isEqualToString:self.masterID] || [slaveIDs containsObject:device.deviceStatus.UUID]) {
            [self.deviceArray addObject:@{@"device":device, @"check":@"1"}];
        }else {
            [self.deviceArray addObject:@{@"device":device, @"check":@"0"}];
        }
    }
}


#pragma mark - tableview datasource
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.deviceArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *kCellIdentifier = @"kCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];

    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier];
    }
    else
    {
        for(UIView * subview in [cell.contentView subviews])
        {
            [subview removeFromSuperview];
        }
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    NSDictionary *dict = self.deviceArray[indexPath.row];
    LPDevice *device = dict[@"device"];
    BOOL isMaster = [device.deviceStatus.UUID isEqualToString:self.masterID] && device.deviceStatus.roomState != LP_ROOM_SLAVE;
    cell.textLabel.text = isMaster ? [NSString stringWithFormat:@"%@ · Ведущая зона", device.deviceStatus.friendlyName] : device.deviceStatus.friendlyName;
    cell.textLabel.font = isMaster ? [UIFont boldSystemFontOfSize:17] : [UIFont systemFontOfSize:17];
    cell.textLabel.textColor = isMaster ? UIColor.systemTealColor : UIColor.labelColor;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    [cell setAccessoryType:[dict[@"check"] isEqualToString:@"1"]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone];
    cell.tintColor = [UIColor colorWithRed:00/255.0 green:178/255.0 blue:142/255.0 alpha:1];;
    UIImageView *lineView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"global_linew"]];
    lineView.frame = CGRectMake(0, 60, self.view.frame.size.width, 1);
    [cell.contentView addSubview:lineView];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.deviceArray[indexPath.row]];
    LPDevice *device = dict[@"device"];
    if ([device.deviceStatus.UUID isEqualToString:self.masterID]) return;
    BOOL isCheck = [dict[@"check"] intValue];
    isCheck = !isCheck;
    [dict setObject:[NSString stringWithFormat:@"%@",@(isCheck)] forKey:@"check"];
    [self.deviceArray replaceObjectAtIndex:indexPath.row withObject:[dict copy]];
    [self.tableView reloadData];
    

}

- (void)doneButtonClick {
    LPDeviceManager *devices = [LPDeviceManager sharedInstance];
    LPDevice *master = self.masterID.length ? [devices deviceForID:self.masterID] : nil;
    if (!master || master.deviceStatus.roomState == LP_ROOM_SLAVE) {
        [self showResult:@"Выберите ведущую зону"];
        return;
    }
    NSArray *currentIDs = [[devices slaveDeviceArray:self.masterID] valueForKeyPath:@"deviceStatus.UUID"];
    NSMutableArray *join = [NSMutableArray array];
    NSMutableArray *leave = [NSMutableArray array];
    for (NSDictionary *row in self.deviceArray) {
        LPDevice *listed = row[@"device"];
        NSString *identity = listed.deviceStatus.UUID;
        if (!identity.length || [identity isEqualToString:self.masterID]) continue;
        BOOL checked = [row[@"check"] boolValue];
        BOOL member = [currentIDs containsObject:identity];
        if (checked == member) continue;
        LPDevice *device = [devices deviceForID:identity];
        if (!device) {
            [self showResult:@"Одна из выбранных зон недоступна"];
            return;
        }
        [(checked ? join : leave) addObject:device];
    }
    self.navigationItem.rightBarButtonItem.enabled = NO;
    LPMultiroomManager *manager = [LPMultiroomManager sharedInstance];
    void (^applyJoin)(BOOL) = ^(BOOL removed) {
        if (!removed || !join.count) {
            [self showResult:removed ? nil : @"Не удалось исключить зоны"];
            return;
        }
        [manager deviceMultiroomWithSlaveDeviceList:join masterDevice:master handler:^(BOOL success) {
            [self showResult:success ? nil : @"Не удалось добавить зоны"];
        }];
    };
    if (leave.count) {
        [manager deviceMultiroomWithSlaveDeviceList:leave masterDevice:nil handler:applyJoin];
    } else {
        applyJoin(YES);
    }
}

- (void)showResult:(NSString *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.navigationItem.rightBarButtonItem.enabled = YES;
        if (self.navigationController.topViewController != self) return;
        if (!error) {
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:error message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
