//  category: alarm
//
//  AlarmClockMainViewController.m
//  iMuzo
//
//  Created by Ning on 15/4/9.
//  Copyright (c) 2015年 wiimu. All rights reserved.
//

#import "AlarmClockMainViewController.h"
#import "AlarmClockAddViewController.h"
#import "AlarmClockTableViewCell.h"
#import "../../ACHome.h"

@interface AlarmClockMainViewController ()
{
    NSMutableArray *alarmArray;
    NSArray *clockNameArray;
    UIButton *editBtn;
}
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *noteLabel;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView;

@end

@implementation AlarmClockMainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.title = ACMenuText(@"Будильники");
    
    self.backgroundImageView.image = [UIImage imageNamed:@"global_default_backgound"];
    self.backgroundImageView.hidden = YES;
    self.tableView.backgroundColor = [UIColor blackColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:.22 alpha:1];
    self.tableView.tableFooterView = [UIView new];

    self.noteLabel.hidden = YES;
    self.noteLabel.text = ACMenuText(@"alarm_You_haven_t_set_up_any_alarms_yet");
    self.noteLabel.font = [UIFont systemFontOfSize:16];
    self.noteLabel.textColor = [UIColor whiteColor];
    
    editBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    editBtn.frame = CGRectMake(0, 0, 34, 34);
    [editBtn setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
    editBtn.tintColor = [UIColor colorWithRed:1 green:.624 blue:.039 alpha:1];
    editBtn.accessibilityLabel = ACMenuText(@"Add Alarm");
    [editBtn addTarget:self action:@selector(addThisBoxClock) forControlEvents:UIControlEventTouchUpInside];
    editBtn.enabled = YES;
    
    UIBarButtonItem *barItem = [[UIBarButtonItem alloc] initWithCustomView:editBtn];
    self.navigationItem.rightBarButtonItem = barItem;
    
    clockNameArray = @[@"clock_1",@"clock_2",@"clock_3",@"clock_4"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self getAlarmClockOfThisBox];
}

- (BOOL)needBackGroundImageView
{
    return NO;
}

-(NSString *)navigationBarTitle
{
    return [@"Alarm_Clock" uppercaseString];
}

- (BOOL)isNavigationBackEnabled
{
    return YES;
}

- (void)addThisBoxClock
{
    //获取新clockname
    NSMutableArray *tempArray = [clockNameArray mutableCopy];
    for (LPAlarmList *obj in alarmArray)
    {
        for (NSString *str in clockNameArray)
        {
            if ([obj.alarmName isEqualToString:str])
            {
                [tempArray removeObject:str];
            }
        }
    }
    
    if (tempArray.count == 0) {
        
        //根据项目需要，自定义个数
        [self.view makeToast:ACMenuText(@"Only supports 4 alarm clocks")];
        return;
    }

    AlarmClockAddViewController *addVC = [[AlarmClockAddViewController alloc] init];
    LPAlarmList *tempObj = [[LPAlarmList alloc] init];
    tempObj.alarmName = tempArray[0];
    tempObj.trigger = LP_ALARM_TRIGGER_ONCE;
    tempObj.type = LP_ALARM_PLAYQUEUE;
    tempObj.volume = @"50";
    tempObj.enable = YES;
    
    addVC.alarmList = tempObj;
    addVC.navigationTitle = ACMenuText(@"Add Alarm");
    addVC.deviceId = self.deviceId;
    [self.navigationController pushViewController:addVC animated:YES];
}

#pragma mark - alarm信息
- (void)getAlarmClockOfThisBox
{
    [self showHud:@""];
    LPDevice *device = [[LPDeviceManager sharedInstance] deviceForID:self.deviceId];
    LPDeiceAlarm *alarm = device.getAlarm;
    [alarm getAlarms:^(NSString * _Nullable alarmString) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHud:@"" afterDelay:0 type:0];
            NSArray *alarmList = [[LPMDPKitManager shared] getAlarmWithString:alarmString];
            self->alarmArray = [[NSMutableArray alloc] initWithArray:alarmList];
            
            if (alarmList.count == 0) {
                self.noteLabel.hidden = NO;
            }else{
                self.noteLabel.hidden = YES;
            }
            [self.tableView reloadData];
        });
    }];
}

#pragma mark- UITableViewDelegate &&UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [alarmArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"clockCell";
    AlarmClockTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil){
        cell = [[[NSBundle mainBundle] loadNibNamed:@"AlarmClockTableViewCell" owner:self options:nil] lastObject];
    }
    cell.backgroundColor = [UIColor colorWithRed:.105 green:.105 blue:.115 alpha:1];
    cell.contentView.backgroundColor = cell.backgroundColor;
    LPAlarmList *alarmObj = alarmArray[indexPath.row];
    
    NSString *currentTimeString = @"";
    NSDate *currentTime =[self getNowDateFromatAnDate:[self dateFromString:alarmObj.time]];
    currentTimeString = [self twStringFromDate:currentTime];
    
    NSArray *tempArray = [currentTimeString componentsSeparatedByString:@" "];
    NSArray *componentArray = [tempArray[1] componentsSeparatedByString:@":"];
    cell.timeLabel.text = [NSString stringWithFormat:@"%@:%@ %@",componentArray[0],componentArray[1],[tempArray count] >2?[tempArray lastObject]:@""];
    cell.timeLabel.textColor = UIColor.whiteColor;
    cell.rateLabel.text = ACMenuText([self accordingToTypeGetRateString:alarmObj.trigger weekDay:alarmObj.repeatArray]);
    cell.rateLabel.textColor = [UIColor colorWithWhite:.66 alpha:1];
    if(alarmObj.enable){
        cell.switchButton.on = YES;
    }else{
        cell.switchButton.on = NO;
    }
    [cell.switchButton addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventTouchUpInside];
    cell.switchButton.tag = indexPath.row;
    cell.switchButton.onTintColor = [UIColor colorWithRed:1 green:.624 blue:.039 alpha:1];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    LPAlarmList *tempObj = alarmArray[indexPath.row];
    
    AlarmClockAddViewController *addVC = [[AlarmClockAddViewController alloc] init];
    addVC.alarmList = tempObj;
    addVC.isFromEdit = YES;
    addVC.navigationTitle = @"Edit Alarm";
    addVC.deviceId = self.deviceId;
    [self.navigationController pushViewController:addVC animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        [self deleteAlarmClock:indexPath];
    }
}

#pragma mark -  privateMethods
- (IBAction)switchAction:(id)sender
{
    UISwitch *switchButton = (UISwitch *)sender;
    LPAlarmList *alarmClock = alarmArray[switchButton.tag];
    
    //获取协议数据
    NSDictionary *alarmDict = [[LPMDPKitManager shared] setAlarmStatusWithOpen:switchButton.on alarmList:alarmClock];
    LPDevice *device = [[LPDeviceManager sharedInstance] deviceForID:self.deviceId];
    LPDeiceAlarm *alarm = device.getAlarm;

    [self showHud:@""];
    [alarm setAlarmSwitchOnWithInfomation:alarmDict completionHandler:^(BOOL isSuccess) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHud:isSuccess?@"success":@"fail" afterDelay:0 type:0];
            [self getAlarmClockOfThisBox];
        });
    }];
}

- (void)deleteAlarmClock:(NSIndexPath *)indexPath
{
    LPAlarmList *alarmClock = alarmArray[indexPath.row];
    LPDevice *device = [[LPDeviceManager sharedInstance] deviceForID:self.deviceId];
    LPDeiceAlarm *alarm = device.getAlarm;
    [self showHud:@""];
    [alarm deleteAlarmWithName:alarmClock.alarmName completionHandler:^(BOOL isSuccess) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHud:isSuccess?@"success":@"fail" afterDelay:0 type:0];
            [self getAlarmClockOfThisBox];
        });
    }];
}

#pragma mark -------- private
- (NSDate *)dateFromString:(NSString *)dateString
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
    NSDate *destDate= [dateFormatter dateFromString:dateString];
    return destDate;
}

- (NSDate *)getNowDateFromatAnDate:(NSDate *)anyDate
{
    //设置源日期时区
    NSTimeZone* sourceTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];//或GMT
    //设置转换后的目标日期时区
    NSTimeZone* destinationTimeZone = [NSTimeZone localTimeZone];
    //得到源日期与世界标准时间的偏移量
    NSInteger sourceGMTOffset = [sourceTimeZone secondsFromGMTForDate:anyDate];
    //目标日期与本地时区的偏移量
    NSInteger destinationGMTOffset = [destinationTimeZone secondsFromGMTForDate:anyDate];
    //得到时间偏移量的差值
    NSTimeInterval interval = destinationGMTOffset - sourceGMTOffset;
    //转为现在时间
    NSDate* destinationDateNow = [[NSDate alloc] initWithTimeInterval:interval sinceDate:anyDate];
    return destinationDateNow;
}
                    
- (NSString *)accordingToTypeGetRateString:(LPAlarmTrigger )trigger weekDay:(NSArray *)weekDay
{
    if (trigger == LP_ALARM_TRIGGER_ONCE)
    {
        return @"alarm_Once";
    }
    else if (trigger == LP_ALARM_TRIGGER_EVERYDAY)
    {
        return @"alarm_Everyday";
    }
    return [self getCurrentAlarmClockString:weekDay];
}

- (NSString *)getCurrentAlarmClockString:(NSArray *)binaryString
{
    NSMutableString *weekString = [[NSMutableString alloc] init];
    for (int i = 0; i< [binaryString count]; i++)
    {
        int binaryDay = [binaryString[i] intValue];
        switch (binaryDay)
        {
            case 0:
                [weekString appendFormat:@" %@", ACMenuText(@"Monday")];
                break;
            case 1:
                [weekString appendFormat:@" %@", ACMenuText(@"Tuesday")];
                break;
            case 2:
                [weekString appendFormat:@" %@", ACMenuText(@"Wednesday")];
                break;
            case 3:
                [weekString appendFormat:@" %@", ACMenuText(@"Thursday")];
                break;
            case 4:
                [weekString appendFormat:@" %@", ACMenuText(@"Friday")];
                break;
            case 5:
                [weekString appendFormat:@" %@", ACMenuText(@"Saturday")];
                break;
            case 6:
                [weekString appendFormat:@" %@", ACMenuText(@"Sunday")];
                break;
            default:
                break;
        }
    }
    if([weekString length] == 0) return nil;
    return weekString;
}

- (NSString *)twStringFromDate:(NSDate *)date
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss a"];
    NSString *destDateString = [dateFormatter stringFromDate:date];
    return destDateString;
}


@end

