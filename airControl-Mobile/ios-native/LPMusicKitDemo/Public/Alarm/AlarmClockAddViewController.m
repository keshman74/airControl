//  category: alarm
//
//  AlarmClockAddViewController.m
//  iMuzo
//
//  Created by Ning on 15/4/9.
//  Copyright (c) 2015年 wiimu. All rights reserved.
//

#import "AlarmClockAddViewController.h"
#import "AlarmClockChooseRateViewController.h"
#import "AlarmSourceObj.h"
#import <objc/runtime.h>
#import "AlarmClockMusicViewController.h"
#import "PresetViewController.h"
#import "../../ACHome.h"

@interface AlarmClockAddViewController ()<AlarmClockChooseRateViewController,AlarmSourceSelectDelegate>
{
    NSArray *optionsList;
 
    NSString *presentQueueName;//闹铃来自预置时的预置名称
    NSMutableArray *daysSpecialArray;//闹铃周期

    UIButton *sureButton;
    UISwitch *repeatSwitch;
    UISlider *alarmVolumeSlider;
    UILabel *repeatDetailLabel;
    UILabel *musicValueLabel;
    UILabel *volumeValueLabel;
    UIScrollView *formScrollView;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIDatePicker *datePicker;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView;

@end

@implementation AlarmClockAddViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    NSString *pageTitle = self.isFromEdit ? @"Edit Alarm" : @"Add Alarm";
    self.title = ACMenuText(pageTitle);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:ACMenuText(@"Cancel")
        style:UIBarButtonItemStylePlain target:self action:@selector(cancelAlarmEditing)];
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];

    sureButton = [UIButton buttonWithType:UIButtonTypeSystem];
    sureButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [sureButton setTitleColor:[UIColor colorWithRed:1 green:.624 blue:.039 alpha:1] forState:UIControlStateNormal];
    [sureButton setTitle:ACMenuText(@"Done") forState:UIControlStateNormal];
    [sureButton addTarget:self action:@selector(finshSetAlarmClock) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:sureButton];

    [self buildAlarmForm];
    [self setUpClockDataSource];
    [self refreshAlarmForm];
}

- (UIColor *)alarmCardColor { return [UIColor colorWithRed:.105 green:.105 blue:.115 alpha:1]; }
- (UIColor *)alarmAccentColor { return [UIColor colorWithRed:1 green:.624 blue:.039 alpha:1]; }

- (UIView *)alarmCardWithHeight:(CGFloat)height {
    UIView *card = [UIView new];
    card.backgroundColor = [self alarmCardColor];
    card.layer.cornerRadius = 18;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = YES;
    [card.heightAnchor constraintEqualToConstant:height].active = YES;
    return card;
}

- (UILabel *)alarmLabel:(NSString *)text size:(CGFloat)size color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    label.textColor = color;
    return label;
}

- (void)buildAlarmForm {
    [self.backgroundImageView removeFromSuperview];
    [self.tableView removeFromSuperview];
    [self.datePicker removeFromSuperview];

    formScrollView = [UIScrollView new];
    formScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    formScrollView.alwaysBounceVertical = YES;
    formScrollView.contentInset = UIEdgeInsetsMake(12, 0, 24, 0);
    [self.view addSubview:formScrollView];
    [NSLayoutConstraint activateConstraints:@[
        [formScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [formScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [formScrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [formScrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    [formScrollView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:formScrollView.contentLayoutGuide.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:formScrollView.contentLayoutGuide.trailingAnchor constant:-18],
        [stack.topAnchor constraintEqualToAnchor:formScrollView.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:formScrollView.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:formScrollView.frameLayoutGuide.widthAnchor constant:-36]
    ]];

    UIView *timeCard = [self alarmCardWithHeight:216];
    UIDatePicker *picker = [UIDatePicker new];
    self.datePicker = picker;
    picker.translatesAutoresizingMaskIntoConstraints = NO;
    picker.datePickerMode = UIDatePickerModeTime;
    picker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    picker.locale = [NSLocale localeWithLocaleIdentifier:NSLocale.preferredLanguages.firstObject ?: @"uk"];
    picker.tintColor = [self alarmAccentColor];
    [timeCard addSubview:picker];
    [NSLayoutConstraint activateConstraints:@[
        [picker.centerXAnchor constraintEqualToAnchor:timeCard.centerXAnchor],
        [picker.centerYAnchor constraintEqualToAnchor:timeCard.centerYAnchor],
        [picker.leadingAnchor constraintGreaterThanOrEqualToAnchor:timeCard.leadingAnchor constant:4],
        [picker.trailingAnchor constraintLessThanOrEqualToAnchor:timeCard.trailingAnchor constant:-4]
    ]];
    [stack addArrangedSubview:timeCard];

    UIView *repeatCard = [self alarmCardWithHeight:76];
    UILabel *repeatTitle = [self alarmLabel:ACMenuText(@"Repeat") size:17 color:UIColor.whiteColor];
    repeatDetailLabel = [self alarmLabel:@"" size:13 color:[UIColor colorWithWhite:.66 alpha:1]];
    UIStackView *repeatLabels = [[UIStackView alloc] initWithArrangedSubviews:@[repeatTitle, repeatDetailLabel]];
    repeatLabels.axis = UILayoutConstraintAxisVertical;
    repeatLabels.spacing = 5;
    repeatSwitch = [UISwitch new];
    repeatSwitch.onTintColor = [self alarmAccentColor];
    [repeatSwitch addTarget:self action:@selector(repeatSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [repeatCard addSubview:repeatLabels]; [repeatCard addSubview:repeatSwitch];
    repeatLabels.translatesAutoresizingMaskIntoConstraints = NO; repeatSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [repeatLabels.leadingAnchor constraintEqualToAnchor:repeatCard.leadingAnchor constant:18],
        [repeatLabels.centerYAnchor constraintEqualToAnchor:repeatCard.centerYAnchor],
        [repeatSwitch.trailingAnchor constraintEqualToAnchor:repeatCard.trailingAnchor constant:-16],
        [repeatSwitch.centerYAnchor constraintEqualToAnchor:repeatCard.centerYAnchor],
        [repeatLabels.trailingAnchor constraintLessThanOrEqualToAnchor:repeatSwitch.leadingAnchor constant:-12]
    ]];
    [stack addArrangedSubview:repeatCard];

    UIButton *musicButton = [UIButton buttonWithType:UIButtonTypeSystem];
    musicButton.backgroundColor = [self alarmCardColor];
    musicButton.layer.cornerRadius = 18;
    musicButton.layer.cornerCurve = kCACornerCurveContinuous;
    musicButton.contentEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 16);
    [musicButton.heightAnchor constraintEqualToConstant:76].active = YES;
    [musicButton addTarget:self action:@selector(chooseAlarmMusic) forControlEvents:UIControlEventTouchUpInside];
    UILabel *musicTitle = [self alarmLabel:ACMenuText(@"Music") size:17 color:UIColor.whiteColor];
    musicValueLabel = [self alarmLabel:@"" size:16 color:[UIColor colorWithWhite:.68 alpha:1]];
    UIImageView *musicChevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    musicChevron.tintColor = [UIColor colorWithWhite:.6 alpha:1];
    UIStackView *musicLabels = [[UIStackView alloc] initWithArrangedSubviews:@[musicTitle, musicValueLabel]];
    musicLabels.axis = UILayoutConstraintAxisVertical; musicLabels.spacing = 5;
    [musicButton addSubview:musicLabels]; [musicButton addSubview:musicChevron];
    musicLabels.translatesAutoresizingMaskIntoConstraints = NO; musicChevron.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [musicLabels.leadingAnchor constraintEqualToAnchor:musicButton.leadingAnchor constant:18],
        [musicLabels.centerYAnchor constraintEqualToAnchor:musicButton.centerYAnchor],
        [musicLabels.trailingAnchor constraintLessThanOrEqualToAnchor:musicChevron.leadingAnchor constant:-12],
        [musicChevron.trailingAnchor constraintEqualToAnchor:musicButton.trailingAnchor constant:-18],
        [musicChevron.centerYAnchor constraintEqualToAnchor:musicButton.centerYAnchor]
    ]];
    [stack addArrangedSubview:musicButton];

    UIView *volumeCard = [self alarmCardWithHeight:116];
    UILabel *volumeTitle = [self alarmLabel:ACMenuText(@"Volume") size:17 color:UIColor.whiteColor];
    volumeValueLabel = [self alarmLabel:@"" size:17 color:UIColor.whiteColor];
    alarmVolumeSlider = [UISlider new];
    alarmVolumeSlider.minimumValue = 0; alarmVolumeSlider.maximumValue = 100;
    alarmVolumeSlider.minimumTrackTintColor = [self alarmAccentColor];
    alarmVolumeSlider.maximumTrackTintColor = [UIColor colorWithWhite:.30 alpha:1];
    alarmVolumeSlider.thumbTintColor = UIColor.whiteColor;
    [alarmVolumeSlider addTarget:self action:@selector(alarmVolumeChanged:) forControlEvents:UIControlEventValueChanged];
    [volumeCard addSubview:volumeTitle]; [volumeCard addSubview:volumeValueLabel]; [volumeCard addSubview:alarmVolumeSlider];
    volumeTitle.translatesAutoresizingMaskIntoConstraints = NO; volumeValueLabel.translatesAutoresizingMaskIntoConstraints = NO; alarmVolumeSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [volumeTitle.leadingAnchor constraintEqualToAnchor:volumeCard.leadingAnchor constant:18],
        [volumeTitle.topAnchor constraintEqualToAnchor:volumeCard.topAnchor constant:17],
        [volumeValueLabel.trailingAnchor constraintEqualToAnchor:volumeCard.trailingAnchor constant:-18],
        [volumeValueLabel.centerYAnchor constraintEqualToAnchor:volumeTitle.centerYAnchor],
        [alarmVolumeSlider.leadingAnchor constraintEqualToAnchor:volumeCard.leadingAnchor constant:16],
        [alarmVolumeSlider.trailingAnchor constraintEqualToAnchor:volumeCard.trailingAnchor constant:-16],
        [alarmVolumeSlider.topAnchor constraintEqualToAnchor:volumeTitle.bottomAnchor constant:15],
        [alarmVolumeSlider.bottomAnchor constraintEqualToAnchor:volumeCard.bottomAnchor constant:-12]
    ]];
    [stack addArrangedSubview:volumeCard];

    UIView *durationCard = [self alarmCardWithHeight:68];
    UILabel *durationTitle = [self alarmLabel:ACMenuText(@"Duration") size:17 color:UIColor.whiteColor];
    UILabel *durationValue = [self alarmLabel:ACMenuText(@"Device default") size:16 color:[UIColor colorWithWhite:.58 alpha:1]];
    [durationCard addSubview:durationTitle]; [durationCard addSubview:durationValue];
    durationTitle.translatesAutoresizingMaskIntoConstraints = NO; durationValue.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [durationTitle.leadingAnchor constraintEqualToAnchor:durationCard.leadingAnchor constant:18],
        [durationTitle.centerYAnchor constraintEqualToAnchor:durationCard.centerYAnchor],
        [durationValue.trailingAnchor constraintEqualToAnchor:durationCard.trailingAnchor constant:-18],
        [durationValue.centerYAnchor constraintEqualToAnchor:durationCard.centerYAnchor]
    ]];
    [stack addArrangedSubview:durationCard];
}

- (void)refreshAlarmForm {
    BOOL repeats = self.alarmList.trigger != LP_ALARM_TRIGGER_ONCE;
    repeatSwitch.on = repeats;
    repeatDetailLabel.text = self.alarmList.trigger == LP_ALARM_TRIGGER_ONCE ? ACMenuText(@"alarm_Once") :
        (self.alarmList.trigger == LP_ALARM_TRIGGER_EVERYDAY ? ACMenuText(@"alarm_Everyday") : ACMenuText(@"alarm_CustomDays"));
    NSString *music = self.alarmList.type == LP_ALARM_PLAYKEYMAP ? presentQueueName : self.alarmList.context;
    musicValueLabel.text = music.length ? ACMenuText([self TodealwithName:music]) : ACMenuText(@"Выбрать пресет");
    NSInteger volume = MAX(0, MIN(100, self.alarmList.volume.integerValue));
    alarmVolumeSlider.value = volume;
    volumeValueLabel.text = [NSString stringWithFormat:@"%ld%%", (long)volume];
}

- (void)repeatSwitchChanged:(UISwitch *)sender {
    if (sender.on) {
        self.alarmList.trigger = LP_ALARM_TRIGGER_EVERYDAY;
        self.alarmList.repeatArray = @[@0,@1,@2,@3,@4,@5,@6];
    } else {
        self.alarmList.trigger = LP_ALARM_TRIGGER_ONCE;
        self.alarmList.repeatArray = @[];
    }
    [self refreshAlarmForm];
}

- (void)alarmVolumeChanged:(UISlider *)sender {
    self.alarmList.volume = [NSString stringWithFormat:@"%.0f", sender.value];
    volumeValueLabel.text = [NSString stringWithFormat:@"%.0f%%", sender.value];
}

- (void)chooseAlarmMusic {
    AlarmSourceObj *source = [GlobalUI sharedInstance].alarmSourceObj;
    source.alarmRootViewController = self;
    source.isEditingAlarmSource = YES;
    PresetViewController *presets = [PresetViewController new];
    presets.title = ACMenuText(@"Музыка из пресетов");
    presets.deviceId = self.deviceId;
    presets.isAddAlarmClock = YES;
    [self.navigationController pushViewController:presets animated:YES];
}

- (void)cancelAlarmEditing { [self.navigationController popViewControllerAnimated:YES]; }

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(NSString *)navigationBarTitle
{
    return [self.navigationTitle uppercaseString];
}

- (BOOL)isNavigationBackEnabled
{
    return YES;
}

#pragma mark- UITableViewDelegate &&UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [optionsList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([optionsList[indexPath.row] isEqualToString:@"slider"]){
        return [self makeVoiceCell:tableView indexPath:indexPath];
    }
    return [self makeCommonCell:tableView indexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *title = optionsList[indexPath.row];
    if ([title isEqualToString:@"alarm_Rate"])
    {
        AlarmClockChooseRateViewController *rateVC = [[AlarmClockChooseRateViewController alloc] init];
        rateVC.delegate = self;
        rateVC.isOnced = self.alarmList.trigger == LP_ALARM_TRIGGER_ONCE?YES:NO;
        rateVC.rateDaysSpecial = self.alarmList.repeatArray;
        [self.navigationController pushViewController:rateVC animated:YES];
    }
    else if([title isEqualToString:@"alarm_Music"])
    {
        AlarmSourceObj *source = [GlobalUI sharedInstance].alarmSourceObj;
        source.alarmRootViewController = self;
        source.isEditingAlarmSource = YES;
        PresetViewController *presets = [PresetViewController new];
        presets.title = ACMenuText(@"Музыка из пресетов");
        presets.deviceId = self.deviceId;
        presets.isAddAlarmClock = YES;
        [self.navigationController pushViewController:presets animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

#pragma mark - makeCell
- (UITableViewCell *)makeVoiceCell:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath
{
    static NSString *kCellIdentifier = @"kCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (cell == nil){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier];
    }else{
        for(UIView * subview in [cell.contentView subviews]){
            [subview removeFromSuperview];
        }
    }
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    //slider
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(80, 0, self.view.frame.size.width - 90, 50)];
    [cell.contentView addSubview:slider];
    slider.minimumValue = 0.0;
    slider.maximumValue = 100.0;
    slider.value = [self.alarmList.volume intValue];
    [slider setContinuous:YES];
    slider.minimumTrackTintColor = [UIColor whiteColor];
    slider.maximumTrackTintColor = [UIColor blueColor];
    slider.thumbTintColor = [UIColor whiteColor];
    [slider addTarget:self action:@selector(sliderValueDidChanged:) forControlEvents:UIControlEventValueChanged];

    UILabel *volumeLabel = [[UILabel alloc] init ];
    volumeLabel.textColor = [UIColor whiteColor];
    volumeLabel.frame = CGRectMake(12, 5, 50, 50);
    volumeLabel.text = self.alarmList.volume;
    [cell.contentView addSubview:volumeLabel];
    return cell;
}

- (void)sliderValueDidChanged:(UISlider *)slider
{
    self.alarmList.volume = [NSString stringWithFormat:@"%d",(int)slider.value];
    [self performSelector:@selector(unlockProgressSlider) withObject:nil afterDelay:1.0];
}

- (void)unlockProgressSlider{
        [self.tableView reloadData];
        [self refreshAlarmForm];
}

- (UITableViewCell *)makeCommonCell:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath
{
    static NSString *kCellIdentifier = @"kCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (cell == nil){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier];
    }else{
        for(UIView * subview in [cell.contentView subviews]){
            [subview removeFromSuperview];
        }
    }

    cell.backgroundColor = [UIColor clearColor];
    NSString *title = optionsList[indexPath.row];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 0, 110, 60)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:17];
    titleLabel.text = [title isEqualToString:@"alarm_Music"] ? ACMenuText(@"Music") : title;
    
    UILabel *chooseLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 0, self.view.frame.size.width-110 -5, 60)];
    chooseLabel.backgroundColor = [UIColor clearColor];
    chooseLabel.textColor = [UIColor lightGrayColor];
    chooseLabel.font = [UIFont systemFontOfSize:17];
    chooseLabel.textAlignment = NSTextAlignmentRight;
    [cell.contentView addSubview:titleLabel];
    [cell.contentView addSubview:chooseLabel];

    if ([title isEqualToString:@"alarm_Volume"])
    {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        chooseLabel.text = [NSString stringWithFormat:@"%@%@",self.alarmList.volume,@"%"];
    }else{
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

    if([title isEqualToString:@"alarm_Music"])
    {
        if (self.alarmList.type == LP_ALARM_PLAYKEYMAP) {
            chooseLabel.text = [self TodealwithName:presentQueueName] ;
        }else{
            chooseLabel.text = [self TodealwithName:self.alarmList.context] ;
        }

        if (self.alarmList.alarmName.length && chooseLabel.text.length >= 8 && [chooseLabel.text hasPrefix:self.alarmList.alarmName]){
            chooseLabel.text = [chooseLabel.text substringFromIndex:8];
        }
        if (!chooseLabel.text.length) chooseLabel.text = ACMenuText(@"Выбрать пресет");
    }else if ([title isEqualToString:@"alarm_Rate"]){
        chooseLabel.text =[self accordingToTypeGetRateString:self.alarmList.trigger weekDay:self.alarmList.repeatArray];
    }
    return cell;
}

-(NSString *)TodealwithName:(NSString *)pendingName
{
    NSString *afterTreatingName=pendingName;
    if ([pendingName length] == 0)
    {
        afterTreatingName = @"alarm_Content_is_empty";
    }
    if ([pendingName isEqualToString:RECENTLY_QUEUE])
    {
        afterTreatingName = @"alarm_Recently_Played";
    }
    if ([pendingName hasPrefix:RECENTLY_QUEUE])
    {
        afterTreatingName = @"alarm_Recently_Played";
    }
    else if ([pendingName isEqualToString:MyFavoriteQueueName])
    {
        afterTreatingName = @"alarm_Favorites";
    }
    else if ([pendingName hasPrefix:MyFavoriteQueueName])
    {
        afterTreatingName = @"alarm_Favorites";
    }
    else if([pendingName hasPrefix:@"WiimuCustomList"])
    {
        NSArray *array = [pendingName componentsSeparatedByString:@"WiimuCustomList_"];
        afterTreatingName = [array lastObject];
    }
    else if ([pendingName rangeOfString:@"_#~"].location != NSNotFound && [pendingName length] > 0)
    {
        NSArray *array = [pendingName componentsSeparatedByString:@"_#~"];
        afterTreatingName = [array firstObject];
    }
    return afterTreatingName;
}

- (void)makeClockTableHeaderViewAndFooterView
{
    self.tableView.scrollEnabled = NO;
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 60)];
    headerView.backgroundColor = [UIColor clearColor];

    UIView *alphaView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 60)];
    alphaView.backgroundColor = [UIColor whiteColor];
    alphaView.alpha = 0.06;
    [headerView addSubview:alphaView];
    self.tableView.tableHeaderView = headerView;

    float height = [UIScreen mainScreen].bounds.size.height - 5*60 - self.navigationController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height - self.datePicker.frame.size.height;
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, height)];
    headerView.backgroundColor = [UIColor clearColor];

    UIView *footerAlphaView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, height)];

    footerAlphaView.backgroundColor = [UIColor whiteColor];
    footerAlphaView.alpha = 0.06;
    [footerView addSubview:footerAlphaView];
    self.tableView.tableFooterView = footerView;
}

#pragma mark - privateMethods
-(void)setUpClockDataSource
{
    if (self.isFromEdit) {
        [self getCurrentCalendarTimer:[self getNowDateFromatAnDate:[self dateFromString:self.alarmList.time]]];
    }else{
        [self getCurrentCalendarTimer:[NSDate date]];
    }
    
    daysSpecialArray = [[NSMutableArray alloc] initWithArray:self.alarmList.repeatArray];
    optionsList = @[@"alarm_Music",@"alarm_Rate", @"alarm_Volume", @"slider"];

    if(self.alarmList.context.length>0)
    {
        presentQueueName = self.alarmList.context;
    }

    if(self.alarmList.type == LP_ALARM_PLAYKEYMAP)
    {
        LPDevice *device = [[LPDeviceManager sharedInstance] deviceForID:self.deviceId];
        LPDevicePreset *devicePreset = device.getPreset;

        [self showHud:@""];
        [devicePreset getPresets:^(int presetNumber, NSString * _Nullable presetString) {

           dispatch_async(dispatch_get_main_queue(), ^{

               NSArray *list = [[LPMDPKitManager shared] getPresetListDataWithNumber:presetNumber presetString:presetString];
               int index =  [self.alarmList.context intValue];
               index = index > 0? index - 1:index;
               LPPlayMusicList *musicList = index < list.count ? list[index] : nil;
               LPPlayHeader *header = musicList.header;
               self->presentQueueName = header.headTitle;
               [self.tableView reloadData];
               [self refreshAlarmForm];

               [self hideHud:@"" type:0];
            });
        }];
    }else{
      [self.tableView reloadData];
    }
}


#pragma mark ---- AlarmSourceSelectDelegate
- (void)alarmSourceLPPlayMusicList:(LPPlayMusicList *)playMusicList
{
    [GlobalUI sharedInstance].alarmSourceObj.isEditingAlarmSource = NO;

    self.alarmList.account = playMusicList.account;
    self.alarmList.header = playMusicList.header;
    self.alarmList.list = playMusicList.list;
    self.alarmList.index = playMusicList.index;
    self.alarmList.type = LP_ALARM_PLAYQUEUE;
    LPPlayItem *item = playMusicList.list.firstObject;
    self.alarmList.context= item.trackName;
    [self.tableView reloadData];
    [self refreshAlarmForm];
}

- (void)alarmPresetIndex:(int)index presetName:(NSString *)presetName
{
    [GlobalUI sharedInstance].alarmSourceObj.isEditingAlarmSource = NO;
    
    self.alarmList.type = LP_ALARM_PLAYKEYMAP;
    self.alarmList.context= [NSString stringWithFormat:@"%d", index + 1];

    NSArray *array = [presetName componentsSeparatedByString:@"_#~"];
    presentQueueName = [array firstObject];
    [self.tableView reloadData];
    [self refreshAlarmForm];
}

#pragma mark ---- AlarmClockChooseRateViewController
- (void)chooseResultRate:(NSDictionary *)dayDictionary isOnlyOnce:(BOOL)isOnce
{
    if (isOnce){
        [daysSpecialArray removeAllObjects];
        if ([dayDictionary[@"chooseKey"] isEqualToString:@"YES"]) {
            self.alarmList.trigger = LP_ALARM_TRIGGER_ONCE;
        }
    }else{
        if([dayDictionary[@"chooseKey"] isEqualToString:@"NO"]){
            
            for (NSNumber *daySpecial in [daysSpecialArray mutableCopy]){
                if (daySpecial == dayDictionary[@"rateIndexKey"]){
                    [daysSpecialArray removeObject:daySpecial];
                }
            }
        }else{
            [daysSpecialArray addObject:dayDictionary[@"rateIndexKey"]];
        }
        self.alarmList.trigger = LP_ALARM_TRIGGER_EVERYWEEK;
        self.alarmList.repeatArray = daysSpecialArray;

        //7天的情况
        if([daysSpecialArray count] == 7){
            self.alarmList.trigger = LP_ALARM_TRIGGER_EVERYDAY;
            self.alarmList.repeatArray = daysSpecialArray;
        }
    }
    [self.tableView reloadData];
}

#pragma mark ----- add new alarm clock
- (void)finshSetAlarmClock
{
    if([self.alarmList.context length] == 0){
        [self.view makeToast:ACMenuText(@"alarm_Please_select_the_alarm_clock_song")];
        return;
    }
    
    [self showHud:@""];
    sureButton.enabled = NO;
    
    //确定闹铃时间
    NSDate *date = self.datePicker.date;
    NSDate *curTime = [NSDate date];
    NSTimeInterval secondsBetweenDates= [curTime timeIntervalSinceDate:date];
    if (secondsBetweenDates >= 0){
        NSTimeInterval interval = 24*3600;
        date= [[NSDate alloc] initWithTimeInterval:interval sinceDate:date];
    }
    NSString *timeStr = [self stringFromDate:date isNeedLocal:YES];
    self.alarmList.time = timeStr;

    LPDevice *device = [[LPDeviceManager sharedInstance] deviceForID:self.deviceId];
    LPDeiceAlarm *alarm = device.getAlarm;

    if (self.isFromEdit) {

        self.alarmList.enable = YES;
        NSDictionary *alarmDict = [[LPMDPKitManager shared] editAlarmWithAlarmList:self.alarmList];
        [alarm editAlarmWithInfomation:alarmDict completionHandler:^(BOOL isSuccess) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->sureButton.enabled = YES;
                [self hideHud:isSuccess?@"success":@"fail" type:0];
                if (isSuccess) {
                    [self.navigationController popViewControllerAnimated:YES];
                }
            });
        }];

    }else{
        NSDictionary *alarmDict = [[LPMDPKitManager shared] addAlarmWithAlarmList:self.alarmList];
        [alarm addAlarmWithInfomation:alarmDict completionHandler:^(BOOL isSuccess) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->sureButton.enabled = YES;
                [self hideHud:isSuccess?@"success":@"fail" type:0];
                if (isSuccess) {
                    [self.navigationController popViewControllerAnimated:YES];
                }
            });
        }];
    }
}

#pragma mark ----- 日期转化
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

- (NSString *)getCurrentAlarmClockString:(NSArray *)dayArray
{
    NSMutableString *weekString = [[NSMutableString alloc] init];
    for (int i = 0; i< [dayArray count]; i++)
    {
        int daysSpecial = [dayArray[i] intValue];
        switch (daysSpecial)
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

- (NSDate *)dateFromString:(NSString *)dateString
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
    NSTimeZone *localTime = [NSTimeZone localTimeZone];
    dateFormatter.timeZone = localTime;
    NSDate *destDate= [dateFormatter dateFromString:dateString];
    return destDate;
}

- (NSString *)stringFromDate:(NSDate *)date isNeedLocal:(BOOL)isNeed
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    if (isNeed)
    {
        NSTimeZone* sourceTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        dateFormatter.timeZone = sourceTimeZone;
    }

    NSString *destDateString = [dateFormatter stringFromDate:date];
    return destDateString;
}

//确定当前pickerview的当前选择row
- (void)getCurrentCalendarTimer:(NSDate *)date
{
    //闹钟时间大于当前时间，默认设置前一天的时间
    NSString *dateStr = @"";
    dateStr = [self stringFromDate:date isNeedLocal:NO];

    NSArray *dateArray = [dateStr componentsSeparatedByString:@" "];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitWeekday | NSCalendarUnitMonth |NSCalendarUnitYear | NSCalendarUnitDay) fromDate:[NSDate date]];
    int year = (int)[components year];
    int month = (int)[components month];
    int day = (int)[components day];
    NSString *timeStr = [NSString stringWithFormat:@"%04d-%02d-%02d %@",year,month,day,dateArray[1]];
    self.datePicker.date = [self dateFromString:timeStr];
    self.datePicker.locale = [NSLocale localeWithLocaleIdentifier:NSLocale.preferredLanguages.firstObject ?: @"uk"];
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

@end


@implementation UILabel (WhiteUIDatePickerLabels)
+ (void)load
{
    [super load];
}

// Forces the text colour of the label to be white only for UIDatePicker and its components
-(void)swizzledSetTextColor:(UIColor *)textColor
{
    if([self view:self hasSuperviewOfClass:[UIDatePicker class]] ||
       [self view:self hasSuperviewOfClass:NSClassFromString(@"UIDatePickerWeekMonthDayView")] ||
       [self view:self hasSuperviewOfClass:NSClassFromString(@"UIDatePickerContentView")]){
        [self swizzledSetTextColor:[UIColor whiteColor]];
    }
    else
    {
        //Carry on with the default
        [self swizzledSetTextColor:textColor];
    }
}

-(void)swizzledSetFont:(UIFont *)font
{
    if([self view:self hasSuperviewOfClass:[UIDatePicker class]] ||
       [self view:self hasSuperviewOfClass:NSClassFromString(@"UIDatePickerWeekMonthDayView")] ||
       [self view:self hasSuperviewOfClass:NSClassFromString(@"UIDatePickerContentView")]){
        [self swizzledSetFont:[UIFont systemFontOfSize:19]];
    }
    else
    {
        [self swizzledSetFont:font];
    }
}

// Some of the UILabels haven't been added to a superview yet so listen for when they do.
- (void)swizzledWillMoveToSuperview:(UIView *)newSuperview {
    [self swizzledSetTextColor:self.textColor];
    [self swizzledSetFont:self.font];
    [self swizzledWillMoveToSuperview:newSuperview];
}

// -- helpers --
- (BOOL)view:(UIView *) view hasSuperviewOfClass:(Class) class {
    if(view.superview){
        if ([view.superview isKindOfClass:class]){
            return true;
        }
        return [self view:view.superview hasSuperviewOfClass:class];
    }
    return false;
}

+ (void)swizzleInstanceSelector:(SEL)originalSelector
                 withNewSelector:(SEL)newSelector
{
    Method originalMethod = class_getInstanceMethod(self, originalSelector);
    Method newMethod = class_getInstanceMethod(self, newSelector);

    BOOL methodAdded = class_addMethod([self class],
                                       originalSelector,
                                       method_getImplementation(newMethod),
                                       method_getTypeEncoding(newMethod));

    if (methodAdded) {
        class_replaceMethod([self class],
                            newSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}


@end
