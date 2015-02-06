//
//  CLStickerTool.m
//
//  Created by sho yakushiji on 2013/12/11.
//  Copyright (c) 2013年 CALACULU. All rights reserved.
//

#import "CLStickerTool.h"

#import "CLCircleView.h"

static NSString* const kCLStickerToolStickerSetInfoKey = @"stickerSetsInfo";
static NSString* const kCLStickerToolDeleteIconName = @"deleteIconAssetsName";
static NSString* const kCLStickerToolStickerWidthKey = @"stickerWidth";
static NSString* const kCLStickerToolStickerImageSize = @"stickerImageSize";
static NSString* const kCLStickerToolStickerSegmentImageNames = @"setSegmentImageNames";

@interface _CLStickerView : UIView
+ (void)setActiveStickerView:(_CLStickerView*)view;
- (UIImageView*)imageView;
- (id)initWithImage:(UIImage *)image tool:(CLStickerTool*)tool;
- (void)setScale:(CGFloat)scale;
@end



@implementation CLStickerTool
{
    UIImage *_originalImage;
    
    UIView *_workingView;
    
    UIScrollView *_menuScroll;
    UIView *_menuFooter;
    UISegmentedControl *_setControl;
}

+ (NSArray*)subtools
{
    return nil;
}

+ (NSString*)defaultTitle
{
    return [CLImageEditorTheme localizedString:@"CLStickerTool_DefaultTitle" withDefault:@"Sticker"];
}

+ (BOOL)isAvailable
{
    return ([UIDevice iosVersion] >= 5.0);
}

+ (CGFloat)defaultDockedNumber
{
    return 7;
}

#pragma mark- optional info

+ (NSString*)defaultStickerPath
{
    return [[[CLImageEditorTheme bundle] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/stickers", NSStringFromClass(self)]];
}

+ (NSDictionary*)optionalInfo
{
    return @{
             kCLStickerToolStickerSetInfoKey: @[@{@"bundlePath": [self defaultStickerPath]}],
             kCLStickerToolDeleteIconName:@"",
             kCLStickerToolStickerWidthKey: @70,
             kCLStickerToolStickerImageSize: @50
             };
}

#pragma mark- implementation

- (void)setup
{
    _originalImage = self.editor.imageView.image;

    [self.editor fixZoomScaleWithAnimated:YES];

    //the footer contains _menuScroll and _setControl
    CGFloat setControlHeight = 37.f;
    CGRect frame = CGRectOffset(self.editor.menuView.frame, 0.f, -setControlHeight);
    frame.size.height += setControlHeight;
    _menuFooter = [[UIView alloc] initWithFrame:frame];
    [self.editor.view addSubview:_menuFooter];

    _menuScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0.f,0.f,self.editor.menuView.frame.size.width,self.editor.menuView.frame.size.height)];
    _menuScroll.backgroundColor = _menuFooter.backgroundColor = self.editor.menuView.backgroundColor;
    _menuScroll.showsHorizontalScrollIndicator = NO;
    [_menuFooter addSubview:_menuScroll];

    //add a separator line
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(_menuScroll.frame.origin.x, _menuScroll.bottom, _menuScroll.frame.size.width, 1.f)];
    separator.backgroundColor = [CLImageEditorTheme backgroundColor];
    [_menuFooter addSubview:separator];

    //add the set control below
    NSArray *sets = self.toolInfo.optionalInfo[kCLStickerToolStickerSetInfoKey];
    _setControl = [self createSegmentControlWithFrame:CGRectMake(_menuScroll.frame.origin.x, separator.bottom, 50*sets.count, setControlHeight) sets:sets];
    [_menuFooter addSubview:_setControl];


    _workingView = [[UIView alloc] initWithFrame:[self.editor.view convertRect:self.editor.imageView.frame fromView:self.editor.imageView.superview]];
    _workingView.clipsToBounds = YES;
    [self.editor.view addSubview:_workingView];
    
    [self setStickerMenuWithSetIndex:0];

    _menuFooter.transform = CGAffineTransformMakeTranslation(0, self.editor.view.height-_menuFooter.top);
    [UIView animateWithDuration:kCLImageToolAnimationDuration
                     animations:^{
                         _menuFooter.transform = CGAffineTransformIdentity;
                     }];
}

- (void)cleanup
{
    [self.editor resetZoomScaleWithAnimated:YES];
    
    [_workingView removeFromSuperview];
    
    [UIView animateWithDuration:kCLImageToolAnimationDuration
                     animations:^{
                         _menuFooter.transform = CGAffineTransformMakeTranslation(0, self.editor.view.height-_menuFooter.top);
                     }
                     completion:^(BOOL finished) {
                         [_menuFooter removeFromSuperview];
                     }];
}

- (void)executeWithCompletionBlock:(void (^)(UIImage *, NSError *, NSDictionary *))completionBlock
{
    [_CLStickerView setActiveStickerView:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [self buildImage:_originalImage];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(image, nil, nil);
        });
    });
}

#pragma mark - Sets

- (UISegmentedControl*)createSegmentControlWithFrame:(CGRect)frame sets:(NSArray*)sets
{
    if (_setControl)
        return _setControl;

    //load sets
    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:sets.count];
    for (NSDictionary *set in sets) {
        if (set[@"setIcon"])
            [items addObject:[[UIImage imageNamed:set[@"setIcon"]] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        else
            [items addObject:[NSString stringWithFormat:@"Set%ld", [sets indexOfObject:set]]];
    }

    UISegmentedControl *setControl = [[UISegmentedControl alloc] initWithItems:items];
    setControl.frame = frame;
    setControl.selectedSegmentIndex = 0;
    if (self.toolInfo.optionalInfo[kCLStickerToolStickerSegmentImageNames])
    {
        UIImage *bg = [UIImage imageNamed:self.toolInfo.optionalInfo[kCLStickerToolStickerSegmentImageNames][@"bg"]];
        UIImage *bgSelected = [UIImage imageNamed:self.toolInfo.optionalInfo[kCLStickerToolStickerSegmentImageNames][@"bg-selected"]];
        UIImage *div = [UIImage imageNamed:self.toolInfo.optionalInfo[kCLStickerToolStickerSegmentImageNames][@"divider"]];
        UIImage *divSelected = [UIImage imageNamed:self.toolInfo.optionalInfo[kCLStickerToolStickerSegmentImageNames][@"divider-selected"]];
        [setControl setBackgroundImage:bg forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [setControl setBackgroundImage:bgSelected forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
        [setControl setDividerImage:div forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [setControl setDividerImage:divSelected forLeftSegmentState:UIControlStateSelected rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [setControl setDividerImage:divSelected forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
        [setControl setDividerImage:divSelected forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [setControl setDividerImage:divSelected forLeftSegmentState:UIControlStateSelected rightSegmentState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [setControl setDividerImage:divSelected forLeftSegmentState:UIControlStateHighlighted rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [setControl setDividerImage:divSelected forLeftSegmentState:UIControlStateHighlighted rightSegmentState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
        [setControl addTarget:self action:@selector(setChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return setControl;
}

- (void)setChanged:(id)sender
{
    //load necessary set
    UISegmentedControl *segmentedControl = (UISegmentedControl*)sender;
    [self setStickerMenuWithSetIndex:segmentedControl.selectedSegmentIndex];
    //scroll to the beginning
    [_menuScroll setContentOffset:CGPointMake(-_menuScroll.contentInset.left, 0) animated:NO];
}

#pragma mark-

- (void)setStickerMenuWithSetIndex:(NSInteger)setIndex
{
    CGFloat W = [self.toolInfo.optionalInfo[kCLStickerToolStickerWidthKey] floatValue];
    CGFloat H = _menuScroll.height;
    CGFloat x = 0, imageSize = [self.toolInfo.optionalInfo[kCLStickerToolStickerImageSize] floatValue];

    NSArray *sets = self.toolInfo.optionalInfo[kCLStickerToolStickerSetInfoKey];
    NSAssert(setIndex < sets.count, @"Index is out of bounds!");

    NSString *stickerPath = sets[setIndex][@"bundlePath"];
    if(stickerPath==nil){ stickerPath = [[self class] defaultStickerPath]; }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error = nil;
    NSArray *list = [fileManager contentsOfDirectoryAtPath:stickerPath error:&error];

    //remove all subviews
    [_menuScroll.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    for(NSString *path in list){
        NSString *filePath = [NSString stringWithFormat:@"%@/%@", stickerPath, path];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        if(image){
            CLToolbarMenuItem *view = [CLImageEditorTheme menuItemWithFrame:CGRectMake(x, 0, W, H) target:self action:@selector(tappedStickerPanel:) toolInfo:nil];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                UIImage *resizedImage = [image aspectFit:CGSizeMake(imageSize, imageSize)];
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    view.iconImage = resizedImage;
                });
            });
            view.userInfo = @{@"filePath" : filePath};
            
            [_menuScroll addSubview:view];
            x += W;
        }
    }
    _menuScroll.contentSize = CGSizeMake(MAX(x, _menuScroll.frame.size.width+1), 0);
}

- (void)tappedStickerPanel:(UITapGestureRecognizer*)sender
{
    UIView *view = sender.view;
    
    NSString *filePath = view.userInfo[@"filePath"];
    if(filePath){
        _CLStickerView *view = [[_CLStickerView alloc] initWithImage:[UIImage imageWithContentsOfFile:filePath] tool:self];
        CGFloat ratio = MIN( (0.5 * _workingView.width) / view.width, (0.5 * _workingView.height) / view.height);
        [view setScale:ratio];
        view.center = CGPointMake(_workingView.width/2, _workingView.height/2);
        
        [_workingView addSubview:view];
        [_CLStickerView setActiveStickerView:view];
    }
    
    view.alpha = 0.2;
    [UIView animateWithDuration:kCLImageToolAnimationDuration
                     animations:^{
                         view.alpha = 1;
                     }
     ];
}

- (UIImage*)buildImage:(UIImage*)image
{
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    
    [image drawAtPoint:CGPointZero];
    
    CGFloat scale = image.size.width / _workingView.width;
    CGContextScaleCTM(UIGraphicsGetCurrentContext(), scale, scale);
    [_workingView.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *tmp = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return tmp;
}

@end

#pragma mark -

@implementation _CLStickerView
{
    UIImageView *_imageView;
    UIButton *_deleteButton;
    CLCircleView *_circleView;
    
    CGFloat _scale;
    CGFloat _arg;
    
    CGPoint _initialPoint;
    CGFloat _initialArg;
    CGFloat _initialScale;
}

+ (void)setActiveStickerView:(_CLStickerView*)view
{
    static _CLStickerView *activeView = nil;
    if(view != activeView){
        [activeView setAvtive:NO];
        activeView = view;
        [activeView setAvtive:YES];
        
        [activeView.superview bringSubviewToFront:activeView];
    }
}

- (id)initWithImage:(UIImage *)image tool:(CLStickerTool*)tool
{
    self = [super initWithFrame:CGRectMake(0, 0, image.size.width+32, image.size.height+32)];
    if(self){
        _imageView = [[UIImageView alloc] initWithImage:image];
        _imageView.layer.borderColor = [[UIColor blackColor] CGColor];
        _imageView.layer.cornerRadius = 3;
        _imageView.center = self.center;
        [self addSubview:_imageView];
        
        _deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
		
        [_deleteButton setImage:[tool imageForKey:kCLStickerToolDeleteIconName defaultImageName:@"btn_delete.png"] forState:UIControlStateNormal];
        _deleteButton.frame = CGRectMake(0, 0, 32, 32);
        _deleteButton.center = _imageView.frame.origin;
        [_deleteButton addTarget:self action:@selector(pushedDeleteBtn:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_deleteButton];
        
        _circleView = [[CLCircleView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
        _circleView.center = CGPointMake(_imageView.width + _imageView.frame.origin.x, _imageView.height + _imageView.frame.origin.y);
        _circleView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        _circleView.radius = 0.7;
        _circleView.color = [UIColor whiteColor];
        _circleView.borderColor = [UIColor blackColor];
        _circleView.borderWidth = 5;
        [self addSubview:_circleView];
        
        _scale = 1;
        _arg = 0;
        
        [self initGestures];
    }
    return self;
}

- (void)initGestures
{
    _imageView.userInteractionEnabled = YES;
    [_imageView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewDidTap:)]];
    [_imageView addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(viewDidPan:)]];
    [_circleView addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(circleViewDidPan:)]];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView* view= [super hitTest:point withEvent:event];
    if(view==self){
        return nil;
    }
    return view;
}

- (UIImageView*)imageView
{
    return _imageView;
}

- (void)pushedDeleteBtn:(id)sender
{
    _CLStickerView *nextTarget = nil;
    
    const NSInteger index = [self.superview.subviews indexOfObject:self];
    
    for(NSInteger i=index+1; i<self.superview.subviews.count; ++i){
        UIView *view = [self.superview.subviews objectAtIndex:i];
        if([view isKindOfClass:[_CLStickerView class]]){
            nextTarget = (_CLStickerView*)view;
            break;
        }
    }
    
    if(nextTarget==nil){
        for(NSInteger i=index-1; i>=0; --i){
            UIView *view = [self.superview.subviews objectAtIndex:i];
            if([view isKindOfClass:[_CLStickerView class]]){
                nextTarget = (_CLStickerView*)view;
                break;
            }
        }
    }
    
    [[self class] setActiveStickerView:nextTarget];
    [self removeFromSuperview];
}

- (void)setAvtive:(BOOL)active
{
    _deleteButton.hidden = !active;
    _circleView.hidden = !active;
    _imageView.layer.borderWidth = (active) ? 1/_scale : 0;
}

- (void)setScale:(CGFloat)scale
{
    _scale = scale;
    
    self.transform = CGAffineTransformIdentity;
    
    _imageView.transform = CGAffineTransformMakeScale(_scale, _scale);
    
    CGRect rct = self.frame;
    rct.origin.x += (rct.size.width - (_imageView.width + 32)) / 2;
    rct.origin.y += (rct.size.height - (_imageView.height + 32)) / 2;
    rct.size.width  = _imageView.width + 32;
    rct.size.height = _imageView.height + 32;
    self.frame = rct;
    
    _imageView.center = CGPointMake(rct.size.width/2, rct.size.height/2);
    
    self.transform = CGAffineTransformMakeRotation(_arg);
    
    _imageView.layer.borderWidth = 1/_scale;
    _imageView.layer.cornerRadius = 3/_scale;
}

- (void)viewDidTap:(UITapGestureRecognizer*)sender
{
    [[self class] setActiveStickerView:self];
}

- (void)viewDidPan:(UIPanGestureRecognizer*)sender
{
    [[self class] setActiveStickerView:self];
    
    CGPoint p = [sender translationInView:self.superview];
    
    if(sender.state == UIGestureRecognizerStateBegan){
        _initialPoint = self.center;
    }
    self.center = CGPointMake(_initialPoint.x + p.x, _initialPoint.y + p.y);
}

- (void)circleViewDidPan:(UIPanGestureRecognizer*)sender
{
    CGPoint p = [sender translationInView:self.superview];
    
    static CGFloat tmpR = 1;
    static CGFloat tmpA = 0;
    if(sender.state == UIGestureRecognizerStateBegan){
        _initialPoint = [self.superview convertPoint:_circleView.center fromView:_circleView.superview];
        
        CGPoint p = CGPointMake(_initialPoint.x - self.center.x, _initialPoint.y - self.center.y);
        tmpR = sqrt(p.x*p.x + p.y*p.y);
        tmpA = atan2(p.y, p.x);
        
        _initialArg = _arg;
        _initialScale = _scale;
    }
    
    p = CGPointMake(_initialPoint.x + p.x - self.center.x, _initialPoint.y + p.y - self.center.y);
    CGFloat R = sqrt(p.x*p.x + p.y*p.y);
    CGFloat arg = atan2(p.y, p.x);
    
    _arg   = _initialArg + arg - tmpA;
    [self setScale:MAX(_initialScale * R / tmpR, 0.2)];
}

@end
