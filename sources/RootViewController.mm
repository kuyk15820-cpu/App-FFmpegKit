#import "RootViewController.h"
#import <ffmpegkit/FFmpegKit.h>
#import <PhotosUI/PhotosUI.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface RootViewController () <UITableViewDelegate, UITableViewDataSource, PHPickerViewControllerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *menuItems;
@property (nonatomic, assign) float currentScale;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end

@implementation RootViewController

// ฟังก์ชันเสริมสำหรับบันทึก Log ลงไฟล์ใน Documents
- (void)logToFile:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString *logMessage = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], message];
    NSLog(@"%@", logMessage);
    
    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *logPath = [docsDir stringByAppendingPathComponent:@"ffmpeg_debug.log"];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (!fileHandle) {
        [[NSData data] writeToFile:logPath atomically:YES];
        fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    }
    
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[logMessage dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    }
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait; 
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // ตั้งค่าพื้นหลังรวมเป็นสีดำสนิทสนมกับ Dark Mode 
    self.view.backgroundColor = [UIColor blackColor];
    self.currentScale = 2.0f; // ค่าเริ่มต้นของ itsscale
    
    if (self.navigationController) {
        self.navigationController.navigationBarHidden = NO;
        self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
        self.navigationController.navigationBar.tintColor = [UIColor systemBlueColor];
        self.title = @"FFmpeg Video Tool";
    }

    [self setupData];
    [self setupTableView];
    [self setupSpinner];
}

- (void)setupData {
    self.menuItems = @[
        @{@"title": @"เลือกวิดีโอจากคลังภาพ (1080p)", @"subtitle": @"ดึงไฟล์ต้นฉบับตรงไม่ผ่านเบราว์เซอร์"},
        @{@"title": @"ตั้งค่าความเร็ว (itsscale)", @"subtitle": @"ปัจจุบัน: 2.0x (สโลว์โมชัน 2 เท่า)"}
    ];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.view addSubview:self.tableView];
}

- (void)setupSpinner {
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.color = [UIColor systemBlueColor];
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
}

#pragma mark - UITableView Quick Setup (Dark Style)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.menuItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"DarkCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1.0]; // สีเทาเข้มหรูหรา
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        
        // เอฟเฟกต์การเลือกสีมืด
        UIView *selectedBG = [[UIView alloc] init];
        selectedBG.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        cell.selectedBackgroundView = selectedBG;
    }
    
    NSDictionary *item = self.menuItems[indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"subtitle"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == 0) {
        [self openSystemPicker];
    } else if (indexPath.row == 1) {
        [self showScaleAlert];
    }
}

#pragma mark - Core Action: การปรับค่าความเร็วผ่าน Alert

- (void)showScaleAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ตั้งค่าตัวคูณเวลา" message:@"ใส่ค่า itsscale ที่ต้องการรันในคำสั่ง FFmpeg (เช่น 2.0 หรือ 0.5)" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.text = [NSString stringWithFormat:@"%.1f", self.currentScale];
    }];
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"ตกลง" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *input = alert.textFields.firstObject;
        if (input.text.floatValue > 0) {
            self.currentScale = input.text.floatValue;
            [self setupData];
            [self.tableView reloadData];
        }
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"ยกเลิก" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:ok];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Core Action: ดึงไฟล์ดิบผ่าน PHPicker (เลี่ยง WebKit Auto-Compress)

- (void)openSystemPicker {
    [self logToFile:@"[START] openSystemPicker ถูกเรียกใช้งาน"];
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
    config.filter = [PHPickerFilter videosFilter];
    config.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent; // จุดสำคัญ: ดึงไฟล์ดิบ ไม่แปลงไฟล์!
    
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [self logToFile:@"[PICKER] didFinishPicking ถูกเรียก, จำนวนวิดีโอที่เลือก: %lu", (unsigned long)results.count];
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    if (results.count == 0) {
        [self logToFile:@"[PICKER] ผู้ใช้ยกเลิกการเลือกไฟล์"];
        return;
    }
    
    [self logToFile:@"[UI] เริ่มแสดงตัว Spinner หมุนโหลด"];
    [self.spinner startAnimating];
    
    PHPickerResult *result = results.firstObject;
    NSItemProvider *provider = result.itemProvider;
    
    // ดึง Type Identifier ของไฟล์วิดีโอต้นฉบับ
    NSString *typeIdentifier = @"public.mpeg-4";
    if (![provider hasItemConformingToTypeIdentifier:typeIdentifier]) {
        if (provider.registeredTypeIdentifiers.count > 0) {
            typeIdentifier = provider.registeredTypeIdentifiers.firstObject;
        }
    }
    [self logToFile:@"[PROVIDER] ใช้ typeIdentifier ในการดึงไฟล์: %@", typeIdentifier];
    
    [self logToFile:@"[PROVIDER] เริ่มเรียก loadFileRepresentationForTypeIdentifier"];
    [provider loadFileRepresentationForTypeIdentifier:typeIdentifier completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
        if (error || !url) {
            [self logToFile:@"[ERROR] loadFileRepresentation ล้มเหลว. Error: %@", error.localizedDescription];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                [self showStatusAlert:@"เกิดข้อผิดพลาดในการดึงไฟล์ต้นฉบับ"];
            });
            return;
        }
        
        [self logToFile:@"[SUCCESS] ได้รับพาร์ทชั่วคราวจากคลังภาพสำเร็จ: %@", url.path];
        
        // ความปลอดภัยระดับสูง: เรียกสิทธิ์ความปลอดภัยเข้าถึงพาร์ทไฟล์แชร์ (Security-Scoped Resource)
        BOOL startAccess = [url startAccessingSecurityScopedResource];
        [self logToFile:@"[SECURITY] ผลลัพธ์การขอสิทธิ์เข้าถึงพาร์ทระบบความปลอดภัย (startAccessing): %d", startAccess];
        
        // คัดลอกวิดีโอไปยังตำแหน่งโฟลเดอร์ชั่วคราวของตัวแอป
        NSString *tempDir = NSTemporaryDirectory();
        NSString *inputPath = [tempDir stringByAppendingPathComponent:@"Test.MP4"];
        NSString *outputPath = [tempDir stringByAppendingPathComponent:@"Test1.MP4"];
        
        [self logToFile:@"[FILE] เตรียมพาร์ทภายในแอป -> Input: %@, Output: %@", inputPath, outputPath];
        
        [[NSFileManager defaultManager] removeItemAtPath:inputPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        
        NSError *copyError = nil;
        BOOL copySuccess = [[NSFileManager defaultManager] copyItemAtPath:url.path toPath:inputPath error:&copyError];
        [self logToFile:@"[FILE] ผลการจำลองไฟล์สำเนาลงพาร์ทแอป: %d, Error: %@", copySuccess, copyError ? copyError.localizedDescription : @"ไม่มี"];
        
        // คืนสิทธิ์การเข้าถึงพาร์ทระบบความปลอดภัยทันทีที่สำเนาไฟล์หลุดมาพาร์ทแอปสำเร็จ
        if (startAccess) {
            [url stopAccessingSecurityScopedResource];
            [self logToFile:@"[SECURITY] ปล่อยสิทธิ์เข้าถึงพาร์ทระบบความปลอดภัย (stopAccessing) เรียบร้อย"];
        }
        
        if (!copySuccess) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                [self showStatusAlert:@"ไม่สามารถสร้างไฟล์สำเนาเพื่อประมวลผลได้"];
            });
            return;
        }
        
        // ประกอบคำสั่งและเริ่มประมวลผลผ่านคลัง FFmpegKit
        NSString *cmd = [NSString stringWithFormat:@"-itsscale %f -i %@ -codec copy %@", self.currentScale, inputPath, outputPath];
        [self logToFile:@"[FFMPEG] เตรียมคำสั่งรัน -> cmd: %@", cmd];
        
        [self logToFile:@"[FFMPEG] เริ่มต้นการเรียกใช้ executeAsync"];
        [FFmpegKit executeAsync:cmd withCompleteCallback:^(id<Session> session) {
            [self logToFile:@"[FFMPEG] executeAsync ทำงานใน Callback สำเร็จ"];
            ReturnCode *code = [session getReturnCode];
            [self logToFile:@"[FFMPEG] รหัสส่งคืนค่าการรัน (ReturnCode): %d", [code getValue]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                if ([ReturnCode isSuccess:code]) {
                    [self logToFile:@"[FFMPEG] แปลงไฟล์สำเร็จ, เตรียมบันทึกกลับลงม้วนฟิล์ม"];
                    // ส่งวิดีโอผลลัพธ์กลับเข้าไปบันทึกไว้ในม้วนฟิล์มคลังภาพ
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:outputPath]];
                    } completionHandler:^(BOOL success, NSError * _Nullable error) {
                        [self logToFile:@"[PHOTOS] ผลลัพธ์การบันทึกลงอัลบั้มภาพ: %d, Error: %@", success, error ? error.localizedDescription : @"ไม่มี"];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (success) {
                                [self showStatusAlert:@"แปลงไฟล์และบันทึกลงคลังภาพความละเอียด 1080p สำเร็จ!"];
                            } else {
                                [self showStatusAlert:@"แปลงสำเร็จแต่บันทึกลงอัลบั้มไม่ได้ ตรวจสอบสิทธิ์เข้าถึงคลังภาพ"];
                            }
                        });
                    }];
                } else {
                    [self logToFile:@"[FFMPEG] คำสั่งรันล้มเหลว (บิลด์ออกไม่สมบูรณ์)"];
                    [self showStatusAlert:@"คำสั่ง FFmpeg ทำงานล้มเหลว"];
                }
            });
        }];
    }];
}

- (void)showStatusAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ระบบทำงาน" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"ตากลบล็อค" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
