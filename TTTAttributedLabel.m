// TTTAttributedLabel.m
//
// Copyright (c) 2011 Mattt Thompson (http://mattt.me)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "TTTAttributedLabel.h"

#define kTTTLineBreakWordWrapTextWidthScalingFactor (M_PI / M_E)

NSString * const kTTTStrikeOutAttributeName = @"TTTStrikeOutAttribute";
NSString * const kTTTBaseFontFromLabelAttributeName = @"TTTBaseFontFromLabelAttributeName";

static inline CTTextAlignment CTTextAlignmentFromUITextAlignment(UITextAlignment alignment) {
	switch (alignment) {
		case UITextAlignmentLeft: return kCTLeftTextAlignment;
		case UITextAlignmentCenter: return kCTCenterTextAlignment;
		case UITextAlignmentRight: return kCTRightTextAlignment;
		default: return kCTNaturalTextAlignment;
	}
}

static inline CTLineBreakMode CTLineBreakModeFromUILineBreakMode(UILineBreakMode lineBreakMode) {
	switch (lineBreakMode) {
		case UILineBreakModeWordWrap: return kCTLineBreakByWordWrapping;
		case UILineBreakModeCharacterWrap: return kCTLineBreakByCharWrapping;
		case UILineBreakModeClip: return kCTLineBreakByClipping;
		case UILineBreakModeHeadTruncation: return kCTLineBreakByTruncatingHead;
		case UILineBreakModeTailTruncation: return kCTLineBreakByTruncatingTail;
		case UILineBreakModeMiddleTruncation: return kCTLineBreakByTruncatingMiddle;
		default: return 0;
	}
}

static inline NSTextCheckingType NSTextCheckingTypeFromUIDataDetectorType(UIDataDetectorTypes dataDetectorType) {
    NSTextCheckingType textCheckingType = 0;
    if (dataDetectorType & UIDataDetectorTypeAddress) {
        textCheckingType |= NSTextCheckingTypeAddress;
    }
    
    if (dataDetectorType & UIDataDetectorTypeCalendarEvent) {
        textCheckingType |= NSTextCheckingTypeDate;
    }
    
    if (dataDetectorType & UIDataDetectorTypeLink) {
        textCheckingType |= NSTextCheckingTypeLink;
    }
    
    if (dataDetectorType & UIDataDetectorTypePhoneNumber) {
        textCheckingType |= NSTextCheckingTypePhoneNumber;
    }
    
    return textCheckingType;
}

static inline NSMutableDictionary * NSAttributedStringAttributesFromLabel(TTTAttributedLabel *label) {
    NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionary]; 
    
    CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)label.font.fontName, label.font.pointSize, NULL);
    [mutableAttributes setObject:(__bridge id)font forKey:(NSString *)kCTFontAttributeName];
    CFRelease(font);
    
    [mutableAttributes setObject:@(YES) forKey:(NSString *)kCTForegroundColorFromContextAttributeName];
    
    CTTextAlignment alignment = CTTextAlignmentFromUITextAlignment((UITextAlignment)label.textAlignment);
    CGFloat lineSpacing = label.leading;
    CGFloat lineHeightMultiple = label.lineHeightMultiple;
    CGFloat topMargin = label.textInsets.top;
    CGFloat bottomMargin = label.textInsets.bottom;
    CGFloat leftMargin = label.textInsets.left;
    CGFloat rightMargin = label.textInsets.right;
    CGFloat firstLineIndent = label.firstLineIndent + leftMargin;

    CTLineBreakMode lineBreakMode;
    if (label.numberOfLines != 1) {
        lineBreakMode = CTLineBreakModeFromUILineBreakMode(UILineBreakModeWordWrap);
    } else {
        lineBreakMode = CTLineBreakModeFromUILineBreakMode((UILineBreakMode)label.lineBreakMode);
    }
	
    CTParagraphStyleSetting paragraphStyles[9] = {
		{.spec = kCTParagraphStyleSpecifierAlignment, .valueSize = sizeof(CTTextAlignment), .value = (const void *)&alignment},
		{.spec = kCTParagraphStyleSpecifierLineBreakMode, .valueSize = sizeof(CTLineBreakMode), .value = (const void *)&lineBreakMode},
        {.spec = kCTParagraphStyleSpecifierLineSpacing, .valueSize = sizeof(CGFloat), .value = (const void *)&lineSpacing},
        {.spec = kCTParagraphStyleSpecifierLineHeightMultiple, .valueSize = sizeof(CGFloat), .value = (const void *)&lineHeightMultiple},
        {.spec = kCTParagraphStyleSpecifierFirstLineHeadIndent, .valueSize = sizeof(CGFloat), .value = (const void *)&firstLineIndent},
        {.spec = kCTParagraphStyleSpecifierParagraphSpacingBefore, .valueSize = sizeof(CGFloat), .value = (const void *)&topMargin},
        {.spec = kCTParagraphStyleSpecifierParagraphSpacing, .valueSize = sizeof(CGFloat), .value = (const void *)&bottomMargin},
        {.spec = kCTParagraphStyleSpecifierHeadIndent, .valueSize = sizeof(CGFloat), .value = (const void *)&leftMargin},
        {.spec = kCTParagraphStyleSpecifierTailIndent, .valueSize = sizeof(CGFloat), .value = (const void *)&rightMargin}
	};

    CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(paragraphStyles, 9);
	[mutableAttributes setObject:(__bridge id)paragraphStyle forKey:(NSString *)kCTParagraphStyleAttributeName];
	CFRelease(paragraphStyle);
    
    return mutableAttributes;
}

static inline NSAttributedString * NSAttributedStringByScalingFontSize(NSAttributedString *attributedString, CGFloat scale, CGFloat minimumFontSize) {
    if (scale == 1.0f) {
        return attributedString;
    }
    
    NSMutableAttributedString *mutableAttributedString = [attributedString mutableCopy];
    [mutableAttributedString enumerateAttribute:(NSString *)kCTFontAttributeName inRange:NSMakeRange(0, [mutableAttributedString length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        CTFontRef font = (__bridge CTFontRef)value;
        if (font) {
            CGFloat scaledFontSize = floorf(CTFontGetSize(font) * scale);
            CTFontRef scaledFont = CTFontCreateCopyWithAttributes(font, fmaxf(scaledFontSize, minimumFontSize), NULL, NULL);
            CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)mutableAttributedString, CFRangeMake(range.location, range.length), kCTFontAttributeName, scaledFont);
            CFRelease(scaledFont);
        }
    }];
    
    return mutableAttributedString;
}

static inline NSAttributedString * NSAttributedStringBySettingColorFromContext(NSAttributedString *attributedString, UIColor *color) {
    if (!color) {
        return attributedString;
    }
    
    CGColorRef colorRef = color.CGColor;
    NSMutableAttributedString *mutableAttributedString = [attributedString mutableCopy];    
    [mutableAttributedString enumerateAttribute:(NSString *)kCTForegroundColorFromContextAttributeName inRange:NSMakeRange(0, [mutableAttributedString length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        CFBooleanRef usesColorFromContext = (__bridge CFBooleanRef)value;
        if (usesColorFromContext && CFBooleanGetValue(usesColorFromContext)) {
            CFRange updateRange = CFRangeMake(range.location, range.length);
            CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)mutableAttributedString, updateRange, kCTForegroundColorAttributeName, colorRef);
            CFAttributedStringRemoveAttribute((__bridge CFMutableAttributedStringRef)mutableAttributedString, updateRange, kCTForegroundColorFromContextAttributeName);
        }
    }];
    
    return mutableAttributedString;    
}

static inline BOOL CTFontContainsSuffix(CTFontRef font, NSString *suffix) {
    if (!font) {
        return NO;
    }
    
    NSString *familyName = CFBridgingRelease(CTFontCopyName(font, kCTFontFamilyNameKey));
    NSString *fontName = CFBridgingRelease(CTFontCopyName(font, kCTFontNameAttribute));

    // Special case for system font
    if ([familyName isEqual:@".Helvetica NeueUI"]) {
        if ([suffix isEqual:@"Medium"]) {
            return [fontName isEqual:@".Helvetica NeueUI"];
        } else {
            return ([suffix length] == 0 || [fontName rangeOfString:suffix].length > 0);
        }
    } else {
        return ([suffix length] == 0 || [fontName rangeOfString:suffix].length > 0);
    }
    
    return NO;
}

static inline CTFontRef CTFontCreateCopyWithStyleSuffix(CTFontRef font, NSString *suffix) {
    if (!font) {
        return NULL;
    }
    
    NSString *returnFontName = nil;
    NSString *familyName = CFBridgingRelease(CTFontCopyName(font, kCTFontFamilyNameKey));

    // Special case for system font
    if ([familyName isEqual:@".Helvetica NeueUI"]) {
        if ([suffix isEqual:@"Medium"]) {
            returnFontName = @".HelveticaNeueUI";
        } else {
            returnFontName = [@".HelveticaNeueUI-" stringByAppendingString:suffix];
        }
    } else {
        for (NSString *fontName in [UIFont fontNamesForFamilyName:familyName]) {
            if (suffix.length == 0 || [fontName rangeOfString:suffix].length > 0) {
                if (returnFontName == nil || fontName.length < returnFontName.length) {
                    returnFontName = fontName;
                }
            }
        }
    }
    
    CTFontRef returnFont = NULL;
    if (returnFontName) {
        returnFont = CTFontCreateWithName((__bridge CFStringRef)returnFontName, CTFontGetSize(font), NULL);
    }
    
    return returnFont;
}

static inline CTFontRef CTFontCreateCopyWithStyleSuffixes(CTFontRef font, NSArray *suffixes) {
    if (!font) {
        return NULL;
    }
    
    for (NSString *suffix in suffixes) {
        CTFontRef styledFont = CTFontCreateCopyWithStyleSuffix(font, suffix);
        
        if (styledFont) {
            return styledFont;
        }
    }
    
    return NULL;
}

static inline CTFontRef CTFontCreateCopyFromBaseFont(CTFontRef font, CTFontRef baseFont) {
    if (!font) {
        CFRetain(baseFont);
        return baseFont;
    }
    
    BOOL isBold = NO;
    BOOL isItalic = NO;
    NSArray *boldItalicSuffixes = [NSArray arrayWithObjects:@"BoldItalic", @"BoldOblique", @"BlackItalic", nil];
    NSArray *boldSuffixes = nil;
    NSArray *italicSuffixes = nil;
    CTFontRef adjustedfont = NULL;

    // Check for Bold & Italic first
    for (NSString *suffix in boldItalicSuffixes) {
        if (CTFontContainsSuffix(font, suffix)) {
            isBold = YES;
            isItalic = YES;
            break;
        }
    }

    if (!isBold && !isItalic) {
        boldSuffixes = [NSArray arrayWithObjects:@"Bold", @"Black", nil];
        
        // If that fails, check for Bold
        for (NSString *suffix in boldSuffixes) {
            if (CTFontContainsSuffix(font, suffix)) {
                isBold = YES;
                break;
            }
        }
        
        // If that fails, check for Italic
        if (!isBold) {
            italicSuffixes = [NSArray arrayWithObjects:@"Italic", @"Oblique", nil];
            
            for (NSString *suffix in italicSuffixes) {
                if (CTFontContainsSuffix(font, suffix)) {
                    isItalic = YES;
                    break;
                }
            }            
        }
    }

    if (isBold && isItalic) {
        adjustedfont = CTFontCreateCopyWithStyleSuffixes(baseFont, boldItalicSuffixes);
    } else if (isBold) {
        adjustedfont = CTFontCreateCopyWithStyleSuffixes(baseFont, boldSuffixes);
    } else if (isItalic) {
        adjustedfont = CTFontCreateCopyWithStyleSuffixes(baseFont, italicSuffixes);
    } else {
        NSArray *normalSuffixes = [NSArray arrayWithObjects:@"Medium", @"", nil];
        adjustedfont = CTFontCreateCopyWithStyleSuffixes(baseFont, normalSuffixes);
    }
    
    return adjustedfont;
}

static inline NSAttributedString * NSAttributedStringBySettingFontFromBaseFont(NSAttributedString *attributedString, UIFont *baseFont) {
    if (!baseFont) {
        return attributedString;
    }
    
    CTFontRef baseFontRef = CTFontCreateWithName((__bridge CFStringRef)baseFont.fontName, baseFont.pointSize, NULL);
    NSMutableAttributedString *mutableAttributedString = [attributedString mutableCopy];
    [mutableAttributedString enumerateAttribute:kTTTBaseFontFromLabelAttributeName inRange:NSMakeRange(0, [mutableAttributedString length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        CFBooleanRef usesFontFromLabel = (__bridge CFBooleanRef)value;
        if (usesFontFromLabel && CFBooleanGetValue(usesFontFromLabel)) {
            CFRange updateRange;
            NSRange effectiveRange;

            CTFontRef currentFont = (__bridge CTFontRef)[mutableAttributedString attribute:(NSString *)kCTFontAttributeName atIndex:range.location effectiveRange:&effectiveRange];            
            if (currentFont) {
                updateRange = CFRangeMake(effectiveRange.location, effectiveRange.length);
            } else {
                updateRange = CFRangeMake(range.location, range.length);                
            }
            
            // There's a chance the adjusted font could have come back as NULL if we couldn't find a sylized version of the base font
            CTFontRef adjustedFont = CTFontCreateCopyFromBaseFont(currentFont, baseFontRef);
            if (adjustedFont) {
                CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)mutableAttributedString, updateRange, kCTFontAttributeName, adjustedFont);
                CFRelease(adjustedFont);
            }

            CFAttributedStringRemoveAttribute((__bridge CFMutableAttributedStringRef)mutableAttributedString, CFRangeMake(range.location, range.length), (__bridge CFStringRef)kTTTBaseFontFromLabelAttributeName);
        }
    }];
    
    CFRelease(baseFontRef);
    return mutableAttributedString;
}

// TODO: Kill this once we have font inheritance working.
static inline NSAttributedString * NSAttributedStringByReplacingFontWithFont(NSAttributedString *attributedString, UIFont *font) {
    if (!font) {
        return attributedString;
    }
    
    CTFontRef fontRef = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
    NSMutableAttributedString *mutableAttributedString = [attributedString mutableCopy];
    [mutableAttributedString enumerateAttribute:(NSString *)kCTFontAttributeName inRange:NSMakeRange(0, [mutableAttributedString length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)mutableAttributedString, CFRangeMake(range.location, range.length), kCTFontAttributeName, fontRef);
    }];
    
    CFRelease(fontRef);
    return mutableAttributedString;
}

@interface TTTAttributedLabel ()
@property (readwrite, nonatomic, copy) NSAttributedString *inactiveAttributedText;
@property (readwrite, nonatomic, copy) NSAttributedString *renderedAttributedText;
@property (readwrite, nonatomic, assign) CTFramesetterRef framesetter;
@property (readwrite, nonatomic, assign) CTFramesetterRef highlightFramesetter;
@property (readwrite, nonatomic, strong) NSDataDetector *dataDetector;
@property (readwrite, nonatomic, strong) NSArray *links;
@property (readwrite, nonatomic, strong) NSTextCheckingResult *activeLink;
@property (readwrite, nonatomic, assign) CGFloat textScaleFactor;
@property (readwrite, nonatomic, assign) BOOL plainText;

- (void)commonInit;
- (void)setNeedsFramesetter;
- (void)setTextAndParseLinks:(NSAttributedString *)attributedText;
- (NSArray *)detectedLinksInString:(NSString *)string range:(NSRange)range error:(NSError **)error;
- (NSTextCheckingResult *)linkAtCharacterIndex:(CFIndex)idx;
- (NSTextCheckingResult *)linkAtPoint:(CGPoint)p;
- (CFIndex)characterIndexAtPoint:(CGPoint)p;
- (void)drawFramesetter:(CTFramesetterRef)framesetter textRange:(CFRange)textRange inRect:(CGRect)rect context:(CGContextRef)c;
- (void)drawStrike:(CTFrameRef)frame inRect:(CGRect)rect context:(CGContextRef)c;
@end

@implementation TTTAttributedLabel {
@private
    BOOL _needsFramesetter;
}

@dynamic text;
@synthesize attributedText = _attributedText;
@synthesize inactiveAttributedText = _inactiveAttributedText;
@synthesize renderedAttributedText = _renderedAttributedText;
@synthesize framesetter = _framesetter;
@synthesize highlightFramesetter = _highlightFramesetter;
@synthesize delegate = _delegate;
@synthesize dataDetectorTypes = _dataDetectorTypes;
@synthesize dataDetector = _dataDetector;
@synthesize links = _links;
@synthesize linkAttributes = _linkAttributes;
@synthesize activeLinkAttributes = _activeLinkAttributes;
@synthesize shadowRadius = _shadowRadius;
@synthesize leading = _leading;
@synthesize lineHeightMultiple = _lineHeightMultiple;
@synthesize firstLineIndent = _firstLineIndent;
@synthesize textInsets = _textInsets;
@synthesize verticalAlignment = _verticalAlignment;
@synthesize activeLink = _activeLink;
@synthesize textScaleFactor = _textScaleFactor;
@synthesize plainText = _plainText;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    
    [self commonInit];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }
    
    [self commonInit];
    
    return self;
}

- (void)commonInit {
    self.dataDetectorTypes = UIDataDetectorTypeNone;
    self.links = [NSArray array];
    
    NSMutableDictionary *mutableLinkAttributes = [NSMutableDictionary dictionary];
    [mutableLinkAttributes setValue:(id)[[UIColor blueColor] CGColor] forKey:(NSString*)kCTForegroundColorAttributeName];
    [mutableLinkAttributes setValue:[NSNumber numberWithBool:YES] forKey:(NSString *)kCTUnderlineStyleAttributeName];
    self.linkAttributes = [NSDictionary dictionaryWithDictionary:mutableLinkAttributes];
    
    NSMutableDictionary *mutableActiveLinkAttributes = [NSMutableDictionary dictionary];
    [mutableActiveLinkAttributes setValue:(id)[[UIColor redColor] CGColor] forKey:(NSString*)kCTForegroundColorAttributeName];
    [mutableActiveLinkAttributes setValue:[NSNumber numberWithBool:YES] forKey:(NSString *)kCTUnderlineStyleAttributeName];
    self.activeLinkAttributes = [NSDictionary dictionaryWithDictionary:mutableActiveLinkAttributes];
    
    self.textInsets = UIEdgeInsetsZero;
    self.textScaleFactor = 1.0f;
    
    self.userInteractionEnabled = YES;
    self.multipleTouchEnabled = NO;
}

- (void)dealloc {
    if (_framesetter) CFRelease(_framesetter);
    if (_highlightFramesetter) CFRelease(_highlightFramesetter);
}

#pragma mark -

- (void)setAttributedText:(NSAttributedString *)text {
    if ([text isEqualToAttributedString:self.attributedText]) {
        return;
    }
    
    [self willChangeValueForKey:@"attributedText"];
    _attributedText = [text copy];
    [self didChangeValueForKey:@"attributedText"];
    
    [self setNeedsFramesetter];
}

- (void)setNeedsFramesetter {
    // Reset the rendered attributed text so it has a chance to regenerate
    self.renderedAttributedText = nil;

    _needsFramesetter = YES;
}

- (CTFramesetterRef)framesetter {
    if (_needsFramesetter) {
        @synchronized(self) {
            if (_framesetter) CFRelease(_framesetter);
            if (_highlightFramesetter) CFRelease(_highlightFramesetter);
            
            self.framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)self.renderedAttributedText);
            self.highlightFramesetter = nil;
            _needsFramesetter = NO;
        }
    }
    
    return _framesetter;
}

- (NSAttributedString *)renderedAttributedText {
    if (!_renderedAttributedText) {
        // Inherit the label's font
        NSAttributedString *adjustedString = NSAttributedStringBySettingFontFromBaseFont(self.attributedText, self.font);
        
        // Inherit the label's textColor
        adjustedString = NSAttributedStringBySettingColorFromContext(adjustedString, self.textColor);
        
        // Adjust the the scale for drawing
        adjustedString = NSAttributedStringByScalingFontSize(adjustedString, self.textScaleFactor, self.minimumFontSize);
        
        self.renderedAttributedText = adjustedString;
    }
    
    return _renderedAttributedText;
}

- (void)setTextScaleFactor:(CGFloat)textScaleFactor {
    if (textScaleFactor != _textScaleFactor) {
        _textScaleFactor = textScaleFactor;
        
        // Give the rendered text a chance to regenerate, but don't redraw since this is an internal adjustment method
        [self setNeedsFramesetter];
    }
}

#pragma mark -

- (void)setLinkActive:(BOOL)active withTextCheckingResult:(NSTextCheckingResult *)result {
    if (result && [self.activeLinkAttributes count] > 0) {
        if (active) {
            if (!self.inactiveAttributedText) {
                self.inactiveAttributedText = self.attributedText;
            }
            
            NSMutableAttributedString *mutableAttributedString = [self.inactiveAttributedText mutableCopy];
            [mutableAttributedString addAttributes:self.activeLinkAttributes range:result.range];
            self.attributedText = mutableAttributedString;
            
            [self setNeedsDisplay];
        } else {
            if (self.inactiveAttributedText) {
                self.attributedText = self.inactiveAttributedText;
                self.inactiveAttributedText = nil;
                
                [self setNeedsDisplay];
            }
        }
    }
}

#pragma mark -

- (void)setDataDetectorTypes:(UIDataDetectorTypes)dataDetectorTypes {
    [self willChangeValueForKey:@"dataDetectorTypes"];
    _dataDetectorTypes = dataDetectorTypes;
    [self didChangeValueForKey:@"dataDetectorTypes"];
    
    if (self.dataDetectorTypes != UIDataDetectorTypeNone) {
        self.dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeFromUIDataDetectorType(self.dataDetectorTypes) error:nil];
    }
}

- (NSArray *)detectedLinksInString:(NSString *)string range:(NSRange)range error:(NSError **)error {
    if (!string || !self.dataDetector) {
        return [NSArray array];
    }
    
    NSMutableArray *mutableLinks = [NSMutableArray array];
    [self.dataDetector enumerateMatchesInString:string options:0 range:range usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [mutableLinks addObject:result];
    }];
    
    return [NSArray arrayWithArray:mutableLinks];
}

- (void)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result attributes:(NSDictionary *)attributes {
    self.links = [self.links arrayByAddingObject:result];
    
    if (attributes) {
        NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
        [mutableAttributedString addAttributes:attributes range:result.range];
        self.attributedText = mutableAttributedString;        
    }
}

- (void)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result {
    [self addLinkWithTextCheckingResult:result attributes:self.linkAttributes];
}

- (void)addLinkToURL:(NSURL *)url withRange:(NSRange)range {
    [self addLinkWithTextCheckingResult:[NSTextCheckingResult linkCheckingResultWithRange:range URL:url]];
}

- (void)addLinkToAddress:(NSDictionary *)addressComponents withRange:(NSRange)range {
    [self addLinkWithTextCheckingResult:[NSTextCheckingResult addressCheckingResultWithRange:range components:addressComponents]];
}

- (void)addLinkToPhoneNumber:(NSString *)phoneNumber withRange:(NSRange)range {
    [self addLinkWithTextCheckingResult:[NSTextCheckingResult phoneNumberCheckingResultWithRange:range phoneNumber:phoneNumber]];
}

- (void)addLinkToDate:(NSDate *)date withRange:(NSRange)range {
    [self addLinkWithTextCheckingResult:[NSTextCheckingResult dateCheckingResultWithRange:range date:date]];
}

- (void)addLinkToDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone duration:(NSTimeInterval)duration withRange:(NSRange)range {
    [self addLinkWithTextCheckingResult:[NSTextCheckingResult dateCheckingResultWithRange:range date:date timeZone:timeZone duration:duration]];
}

#pragma mark -

- (NSTextCheckingResult *)linkAtCharacterIndex:(CFIndex)idx {
    for (NSTextCheckingResult *result in self.links) {
        NSRange range = result.range;
        if ((CFIndex)range.location <= idx && idx <= (CFIndex)(range.location + range.length - 1)) {
            return result;
        }
    }
    
    return nil;
}

- (NSTextCheckingResult *)linkAtPoint:(CGPoint)p {
    CFIndex idx = [self characterIndexAtPoint:p];
    return [self linkAtCharacterIndex:idx];
}

- (CFIndex)characterIndexAtPoint:(CGPoint)p {
    if (!CGRectContainsPoint(self.bounds, p)) {
        return NSNotFound;
    }
    
    CGRect textRect = [self textRectForBounds:self.bounds limitedToNumberOfLines:self.numberOfLines];
    if (!CGRectContainsPoint(textRect, p)) {
        return NSNotFound;
    }
    
    // Offset tap coordinates by textRect origin to make them relative to the origin of frame
    p = CGPointMake(p.x - textRect.origin.x, p.y - textRect.origin.y);
    // Convert tap coordinates (start at top left) to CT coordinates (start at bottom left)
    p = CGPointMake(p.x, textRect.size.height - p.y);

    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, textRect);
    CTFrameRef frame = CTFramesetterCreateFrame(self.framesetter, CFRangeMake(0, [self.renderedAttributedText length]), path, NULL);
    if (frame == NULL) {
        CFRelease(path);
        return NSNotFound;
    }

    CFArrayRef lines = CTFrameGetLines(frame);
    NSInteger numberOfLines = self.numberOfLines > 0 ? MIN(self.numberOfLines, CFArrayGetCount(lines)) : CFArrayGetCount(lines);
    if (numberOfLines == 0) {
        CFRelease(frame);
        CFRelease(path);
        return NSNotFound;
    }
    
    NSUInteger idx = NSNotFound;

    CGPoint lineOrigins[numberOfLines];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), lineOrigins);

    for (CFIndex lineIndex = 0; lineIndex < numberOfLines; lineIndex++) {
        CGPoint lineOrigin = lineOrigins[lineIndex];
        CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
        
        // Get bounding information of line
        CGFloat ascent, descent, leading, width;
        width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        CGFloat yMin = floor(lineOrigin.y - descent);
        CGFloat yMax = ceil(lineOrigin.y + ascent);
        
        // Check if we've already passed the line
        if (p.y > yMax) {
            break;
        }
        // Check if the point is within this line vertically
        if (p.y >= yMin) {
            // Check if the point is within this line horizontally
            if (p.x >= lineOrigin.x && p.x <= lineOrigin.x + width) {
                // Convert CT coordinates to line-relative coordinates
                CGPoint relativePoint = CGPointMake(p.x - lineOrigin.x, p.y - lineOrigin.y);
                idx = CTLineGetStringIndexForPosition(line, relativePoint);
                break;
            }
        }
    }
    
    CFRelease(frame);
    CFRelease(path);
        
    return idx;
}

- (void)drawFramesetter:(CTFramesetterRef)framesetter textRange:(CFRange)textRange inRect:(CGRect)rect context:(CGContextRef)c {
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, rect);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, textRange, path, NULL);    
    
    CFArrayRef lines = CTFrameGetLines(frame);
    NSInteger numberOfLines = self.numberOfLines > 0 ? MIN(self.numberOfLines, CFArrayGetCount(lines)) : CFArrayGetCount(lines);
    BOOL truncateLastLine = (self.lineBreakMode == UILineBreakModeHeadTruncation || self.lineBreakMode == UILineBreakModeMiddleTruncation || self.lineBreakMode == UILineBreakModeTailTruncation);
	
    CGPoint lineOrigins[numberOfLines];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, numberOfLines), lineOrigins);
        
    for (CFIndex lineIndex = 0; lineIndex < numberOfLines; lineIndex++) {
        CGPoint lineOrigin = lineOrigins[lineIndex];
        CGContextSetTextPosition(c, lineOrigin.x, lineOrigin.y);
        CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
        
        if (lineIndex == numberOfLines - 1 && truncateLastLine) {
            // Check if the range of text in the last line reaches the end of the full attributed string
            CFRange lastLineRange = CTLineGetStringRange(line);
            
            if (!(lastLineRange.length == 0 && lastLineRange.location == 0) && lastLineRange.location + lastLineRange.length < textRange.location + textRange.length) {
                // Get correct truncationType and attribute position
                CTLineTruncationType truncationType;
                NSUInteger truncationAttributePosition = lastLineRange.location;
                UILineBreakMode lineBreakMode = (UILineBreakMode)self.lineBreakMode;
                
                // Multiple lines, only use UILineBreakModeTailTruncation
                if (numberOfLines != 1) {
                    lineBreakMode = UILineBreakModeTailTruncation;
                }
                
                switch (lineBreakMode) {
                    case UILineBreakModeHeadTruncation:
                        truncationType = kCTLineTruncationStart;
                        break;
                    case UILineBreakModeMiddleTruncation:
                        truncationType = kCTLineTruncationMiddle;
                        truncationAttributePosition += (lastLineRange.length / 2);
                        break;
                    case UILineBreakModeTailTruncation:
                    default:
                        truncationType = kCTLineTruncationEnd;
                        truncationAttributePosition += (lastLineRange.length - 1);
                        break;
                }
                
                // Get the attributes and use them to create the truncation token string
                NSDictionary *tokenAttributes = [self.renderedAttributedText attributesAtIndex:truncationAttributePosition effectiveRange:NULL];
                // \u2026 is the Unicode horizontal ellipsis character code
                NSAttributedString *tokenString = [[NSAttributedString alloc] initWithString:@"\u2026" attributes:tokenAttributes];
                CTLineRef truncationToken = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)tokenString);
                
                // Append truncationToken to the string
                // because if string isn't too long, CT wont add the truncationToken on it's own
                // There is no change of a double truncationToken because CT only add the token if it removes characters (and the one we add will go first)
                NSMutableAttributedString *truncationString = [[self.renderedAttributedText attributedSubstringFromRange:NSMakeRange(lastLineRange.location, lastLineRange.length)] mutableCopy];
                if (lastLineRange.length > 0) {
                    // Remove any newline at the end (we don't want newline space between the text and the truncation token). There can only be one, because the second would be on the next line.
                    unichar lastCharacter = [[truncationString string] characterAtIndex:lastLineRange.length - 1];
                    if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastCharacter]) {
                        [truncationString deleteCharactersInRange:NSMakeRange(lastLineRange.length - 1, 1)];
                    }
                }
                [truncationString appendAttributedString:tokenString];
                CTLineRef truncationLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)truncationString);

                // Truncate the line in case it is too long.
                CTLineRef truncatedLine = CTLineCreateTruncatedLine(truncationLine, rect.size.width, truncationType, truncationToken);
                if (!truncatedLine) {
                    // If the line is not as wide as the truncationToken, truncatedLine is NULL
                    truncatedLine = CFRetain(truncationToken);
                }
                
                CTLineDraw(truncatedLine, c);
                
                CFRelease(truncatedLine);
                CFRelease(truncationLine);
                CFRelease(truncationToken);
            } else {
                CTLineDraw(line, c);
            }
        } else {
            CTLineDraw(line, c);
        }
    }
    
    [self drawStrike:frame inRect:rect context:c];
        
    CFRelease(frame);
    CFRelease(path);    
}

- (void)drawStrike:(CTFrameRef)frame inRect:(CGRect)rect context:(CGContextRef)c {
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
    CGPoint origins[[lines count]];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
    
    CFIndex lineIndex = 0;
    for (id line in lines) {        
        CGRect lineBounds = CTLineGetImageBounds((__bridge CTLineRef)line, c);
        lineBounds.origin.x = origins[lineIndex].x;
        lineBounds.origin.y = origins[lineIndex].y;
        
        for (id glyphRun in (__bridge NSArray *)CTLineGetGlyphRuns((__bridge CTLineRef)line)) {
            NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes((__bridge CTRunRef) glyphRun);
            BOOL strikeOut = [[attributes objectForKey:kTTTStrikeOutAttributeName] boolValue];
            NSInteger superscriptStyle = [[attributes objectForKey:(id)kCTSuperscriptAttributeName] integerValue];
            
            if (strikeOut) {
                CGRect runBounds = CGRectZero;
                CGFloat ascent = 0.0f;
                CGFloat descent = 0.0f;
                
                runBounds.size.width = CTRunGetTypographicBounds((__bridge CTRunRef)glyphRun, CFRangeMake(0, 0), &ascent, &descent, NULL);
                runBounds.size.height = ascent + descent;
                
                CGFloat xOffset = CTLineGetOffsetForStringIndex((__bridge CTLineRef)line, CTRunGetStringRange((__bridge CTRunRef)glyphRun).location, NULL);
                runBounds.origin.x = origins[lineIndex].x + rect.origin.x + xOffset;
                runBounds.origin.y = origins[lineIndex].y + rect.origin.y;
                runBounds.origin.y -= descent;
                
                // Don't draw strikeout too far to the right
                if (CGRectGetWidth(runBounds) > CGRectGetWidth(lineBounds)) {
                    runBounds.size.width = CGRectGetWidth(lineBounds);
                }
                
				switch (superscriptStyle) {
					case 1:
						runBounds.origin.y -= ascent * 0.47f;
						break;
					case -1:
						runBounds.origin.y += ascent * 0.25f;
						break;
					default:
						break;
				}
                
                // Use text color, or default to black
                id color = [attributes objectForKey:(id)kCTForegroundColorAttributeName];

                if (color) {
                    CGContextSetStrokeColorWithColor(c, (__bridge CGColorRef)color);
                } else {
                    CGContextSetGrayStrokeColor(c, 0.0f, 1.0);
                }
                
                CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)self.font.fontName, self.font.pointSize, NULL);
                CGContextSetLineWidth(c, CTFontGetUnderlineThickness(font));
                CGFloat y = roundf(runBounds.origin.y + runBounds.size.height / 2.0f);
                CGContextMoveToPoint(c, runBounds.origin.x, y);
                CGContextAddLineToPoint(c, runBounds.origin.x + runBounds.size.width, y);
                
                CGContextStrokePath(c);
                CFRelease(font);
            }
        }
        
        lineIndex++;
    }
}

#pragma mark - TTTAttributedLabel

- (void)setText:(id)text {
    if ([text isKindOfClass:[NSString class]]) {
        [self setText:text afterInheritingLabelAttributesAndConfiguringWithBlock:nil];
    } else if ([text isKindOfClass:[NSAttributedString class]]) {
        [self setTextAndParseLinks:text];
    }
}

- (void)setTextAndParseLinks:(NSAttributedString *)attributedText {
    self.attributedText = attributedText;
    
    self.links = [NSArray array];
    if (self.dataDetectorTypes != UIDataDetectorTypeNone) {
        for (NSTextCheckingResult *result in [self detectedLinksInString:[self.attributedText string] range:NSMakeRange(0, [attributedText length]) error:nil]) {
            [self addLinkWithTextCheckingResult:result];
        }
    }
    
    [super setText:[self.attributedText string]];    
}

- (void)setText:(id)text afterInheritingLabelAttributesAndConfiguringWithBlock:(NSMutableAttributedString *(^)(NSMutableAttributedString *mutableAttributedString))block {    
    NSMutableAttributedString *mutableAttributedString = nil;
    if ([text isKindOfClass:[NSString class]]) {
        self.plainText = YES;
        mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:text attributes:NSAttributedStringAttributesFromLabel(self)];
    } else {
        // Only replace attributes that aren't already specified in the supplied string.
        NSMutableDictionary *attributesToInherit = NSAttributedStringAttributesFromLabel(self);
        NSDictionary *existingAttributes = [text attributesAtIndex:0 effectiveRange:NULL];
        [attributesToInherit removeObjectsForKeys:existingAttributes.allKeys];
        
        mutableAttributedString = [text mutableCopy];
        [mutableAttributedString addAttributes:attributesToInherit range:NSMakeRange(0, [mutableAttributedString length])];
    }
    
    if (block) {
        mutableAttributedString = block(mutableAttributedString);
    }
    
    [self setTextAndParseLinks:mutableAttributedString];
}

#pragma mark - UILabel

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}

// Fixes crash when loading from a UIStoryboard
- (UIColor *)textColor {
	UIColor *color = [super textColor];
	if (!color) {
		color = [UIColor blackColor];
	}
	
	return color;
}

- (void)setTextColor:(UIColor *)textColor {
    UIColor *oldTextColor = self.textColor;
    [super setTextColor:textColor];

    // Redraw to allow any ColorFromContext attributes a chance to update
    if (textColor != oldTextColor) {
        [self setNeedsFramesetter];
        [self setNeedsDisplay];
    }
}

- (void)setFont:(UIFont *)font {
    UIFont *oldFont = self.font;
    [super setFont:font];
        
    // Redraw to allow any BaseFontFromLabel attributes a chance to update
    if (font != oldFont) {
        // TODO: Kill this once we have font inheritance working.
        if (self.plainText) {
            [self setTextAndParseLinks:NSAttributedStringByReplacingFontWithFont(self.attributedText, font)];
        }
        
        [self setNeedsFramesetter];
        [self setNeedsDisplay];
    }
}

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines {
    if (!self.renderedAttributedText) {
        return [super textRectForBounds:bounds limitedToNumberOfLines:numberOfLines];
    }
        
    CGRect textRect;
    textRect.origin = bounds.origin;
    
    // Measure the size with CoreText.
    textRect.size = CTFramesetterSuggestFrameSizeWithConstraints(self.framesetter, CFRangeMake(0, [self.renderedAttributedText length]), NULL, bounds.size, NULL);
    textRect.size = CGSizeMake(ceilf(CGRectGetWidth(textRect)), ceilf(CGRectGetHeight(textRect)));  // Fix for iOS 4, CTFramesetterSuggestFrameSizeWithConstraints sometimes returns fractional sizes
    
    // Take vertical alignment into account.
    if (CGRectGetHeight(bounds) != CGFLOAT_MAX && CGRectGetHeight(textRect) < CGRectGetHeight(bounds)) {
        if (self.verticalAlignment == TTTAttributedLabelVerticalAlignmentCenter) {
            textRect.origin.y = floorf(CGRectGetMidY(bounds) - CGRectGetHeight(textRect) / 2.0f);
        } else if (self.verticalAlignment == TTTAttributedLabelVerticalAlignmentBottom) {
            textRect.origin.y = CGRectGetMaxY(bounds) - CGRectGetHeight(textRect);
        }
    }
    
    return textRect;
}

- (void)drawTextInRect:(CGRect)rect {
    if (!self.renderedAttributedText) {
        [super drawTextInRect:rect];
        return;
    }
        
    // Adjust the font size to fit width, if necessarry 
    if (self.adjustsFontSizeToFitWidth && self.numberOfLines > 0) {
        CGFloat textWidth = [self sizeThatFits:CGSizeZero].width;
        CGFloat availableWidth = self.frame.size.width * self.numberOfLines;
        if (self.numberOfLines > 1 && self.lineBreakMode == UILineBreakModeWordWrap) {
            textWidth *= kTTTLineBreakWordWrapTextWidthScalingFactor;
        }
        
        if (textWidth > availableWidth && textWidth > 0.0f) {
            self.textScaleFactor = (availableWidth / textWidth);
        } else {
            self.textScaleFactor = 1.0f;            
        }
    } else {
        self.textScaleFactor = 1.0f;
    }
    
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetTextMatrix(c, CGAffineTransformIdentity);

    // Inverts the CTM to match iOS coordinates (otherwise text draws upside-down; Mac OS's system is different)
    CGContextTranslateCTM(c, 0.0f, rect.size.height);
    CGContextScaleCTM(c, 1.0f, -1.0f);
    
    CFRange textRange = CFRangeMake(0, [self.renderedAttributedText length]);

    // First, get the text rect (which takes vertical centering into account)
    CGRect textRect = [self textRectForBounds:rect limitedToNumberOfLines:self.numberOfLines];

    // CoreText draws it's text aligned to the bottom, so we move the CTM here to take our vertical offsets into account
    CGContextTranslateCTM(c, 0.0f, rect.size.height - textRect.origin.y - textRect.size.height);

    // Second, trace the shadow before the actual text, if we have one
    if (self.shadowColor && !self.highlighted) {
        CGContextSetShadowWithColor(c, self.shadowOffset, self.shadowRadius, [self.shadowColor CGColor]);
    }
    
    // Finally, draw the text or highlighted text itself (on top of the shadow, if there is one)
    if (self.highlightedTextColor && self.highlighted) {
        if (!self.highlightFramesetter) {
            NSMutableAttributedString *mutableAttributedString = [self.renderedAttributedText mutableCopy];
            [mutableAttributedString addAttribute:(NSString *)kCTForegroundColorAttributeName value:(id)[self.highlightedTextColor CGColor] range:NSMakeRange(0, mutableAttributedString.length)];
            self.highlightFramesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)mutableAttributedString);
        }
        
        [self drawFramesetter:self.highlightFramesetter textRange:textRange inRect:textRect context:c];
    } else {
        [self drawFramesetter:self.framesetter textRange:textRange inRect:textRect context:c];
    }  
    
    // If we adjusted the font size, set it back to its original size
    self.textScaleFactor = 1.0f;
}

#pragma mark - UIView

- (CGSize)sizeThatFits:(CGSize)size {
    if (!self.renderedAttributedText) {
        return [super sizeThatFits:size];
    }
    
    CFRange rangeToSize = CFRangeMake(0, [self.renderedAttributedText length]);
    CGSize constraints = CGSizeMake(size.width, CGFLOAT_MAX);
    
    if (self.numberOfLines == 1) {
        // If there is one line, the size that fits is the full width of the line
        constraints = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    } else if (self.numberOfLines > 0) {
        // If the line count of the label more than 1, limit the range to size to the number of lines that have been set
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathAddRect(path, NULL, CGRectMake(0.0f, 0.0f, constraints.width, CGFLOAT_MAX));
        CTFrameRef frame = CTFramesetterCreateFrame(self.framesetter, CFRangeMake(0, 0), path, NULL);
        CFArrayRef lines = CTFrameGetLines(frame);
        
        if (CFArrayGetCount(lines) > 0) {
            NSInteger lastVisibleLineIndex = MIN(self.numberOfLines, CFArrayGetCount(lines)) - 1;
            CTLineRef lastVisibleLine = CFArrayGetValueAtIndex(lines, lastVisibleLineIndex);
            
            CFRange rangeToLayout = CTLineGetStringRange(lastVisibleLine);
            rangeToSize = CFRangeMake(0, rangeToLayout.location + rangeToLayout.length);
        }
        
        CFRelease(frame);
        CFRelease(path);
    }
    
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(self.framesetter, rangeToSize, NULL, constraints, NULL);
    
    return CGSizeMake(ceilf(suggestedSize.width), ceilf(suggestedSize.height));
}

#pragma mark - UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    
    self.activeLink = [self linkAtPoint:[touch locationInView:self]];
        
    if (self.activeLink) {
        [self setLinkActive:YES withTextCheckingResult:self.activeLink];
    } else {
        [super touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {    
    if (self.activeLink) {
        UITouch *touch = [touches anyObject];
        
        if (self.activeLink != [self linkAtPoint:[touch locationInView:self]]) {
            [self setLinkActive:NO withTextCheckingResult:self.activeLink];
        } else {
            [self setLinkActive:YES withTextCheckingResult:self.activeLink];
        }
    } else {
        [super touchesMoved:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.activeLink) {
        UITouch *touch = [touches anyObject];
        if (self.activeLink == [self linkAtPoint:[touch locationInView:self]]) {
            [self setLinkActive:NO withTextCheckingResult:self.activeLink];
            
            if (!self.delegate) {
                return;
            }
            
            NSTextCheckingResult *result = self.activeLink;
            switch (result.resultType) {
                case NSTextCheckingTypeLink:
                    if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithURL:)]) {
                        [self.delegate attributedLabel:self didSelectLinkWithURL:result.URL];
                        return;
                    }
                    break;
                case NSTextCheckingTypeAddress:
                    if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithAddress:)]) {
                        [self.delegate attributedLabel:self didSelectLinkWithAddress:result.addressComponents];
                        return;
                    }
                    break;
                case NSTextCheckingTypePhoneNumber:
                    if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithPhoneNumber:)]) {
                        [self.delegate attributedLabel:self didSelectLinkWithPhoneNumber:result.phoneNumber];
                        return;
                    }
                    break;
                case NSTextCheckingTypeDate:
                    if (result.timeZone && [self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithDate:timeZone:duration:)]) {
                        [self.delegate attributedLabel:self didSelectLinkWithDate:result.date timeZone:result.timeZone duration:result.duration];
                        return;
                    } else if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithDate:)]) {
                        [self.delegate attributedLabel:self didSelectLinkWithDate:result.date];
                        return;
                    }
                    break;
                default:
                    break;
            }
            
            // Fallback to `attributedLabel:didSelectLinkWithTextCheckingResult:` if no other delegate method matched.
            if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithTextCheckingResult:)]) {
                [self.delegate attributedLabel:self didSelectLinkWithTextCheckingResult:result];
            }
        }
    } else {
        [super touchesEnded:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.activeLink) {
        [self setLinkActive:NO withTextCheckingResult:self.activeLink];
    } else {
        [super touchesCancelled:touches withEvent:event];
    }
}

@end
