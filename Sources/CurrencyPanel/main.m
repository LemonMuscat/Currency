#import <Cocoa/Cocoa.h>

static NSString * const SnapshotKey = @"CurrencyPanel.previousSnapshot";
static NSString * const SelectedCodesKey = @"CurrencyPanel.selectedCodes";
static NSString * const CalculatorCodesKey = @"CurrencyPanel.calculatorCodes";
static NSString * const USDAmountKey = @"CurrencyPanel.usdAmount";
static NSTimeInterval const RefreshInterval = 300;

@interface CurrencyItem : NSObject
@property (nonatomic, copy) NSString *code;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *country;
@property (nonatomic, copy) NSString *flag;
+ (instancetype)itemWithCode:(NSString *)code name:(NSString *)name country:(NSString *)country flag:(NSString *)flag;
@end

@implementation CurrencyItem
+ (instancetype)itemWithCode:(NSString *)code name:(NSString *)name country:(NSString *)country flag:(NSString *)flag {
    CurrencyItem *item = [CurrencyItem new];
    item.code = code;
    item.name = name;
    item.country = country;
    item.flag = flag;
    return item;
}
@end

@interface RateStore : NSObject
@property (nonatomic) double usdAmount;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *rates;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *previousRates;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *usdRates;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedCodes;
@property (nonatomic, strong) NSDate *lastUpdated;
@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, copy) NSString *sourceName;
@property (nonatomic) BOOL loading;
@property (nonatomic, copy) void (^onChange)(void);
- (NSArray<CurrencyItem *> *)selectedCurrencies;
- (void)start;
- (void)refresh;
- (void)fetchNaverRates;
- (void)fetchYahooRates;
- (void)fetchFallbackRates;
- (void)toggleCurrency:(CurrencyItem *)currency;
- (double)usdRateForCode:(NSString *)code available:(BOOL *)available;
- (double)convertedValueForCode:(NSString *)code available:(BOOL *)available;
- (double)krwValueForCode:(NSString *)code unit:(double)unit available:(BOOL *)available;
- (double)deltaPercentForCode:(NSString *)code available:(BOOL *)available;
- (double)krwCrossForCode:(NSString *)code available:(BOOL *)available;
- (double)krwCrossDeltaForCode:(NSString *)code available:(BOOL *)available;
@end

static NSArray<NSString *> *DefaultCalculatorCodes(void) {
    return @[@"USD", @"KRW", @"JPY", @"CNY", @"EUR", @"THB", @"VND"];
}

static NSString *YahooKRWSymbolForCode(NSString *code) {
    if ([code isEqualToString:@"KRW"]) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@KRW=X", code];
}

static NSString *YahooUSDSymbolForCode(NSString *code) {
    if ([code isEqualToString:@"USD"]) {
        return nil;
    }
    return [NSString stringWithFormat:@"USD%@=X", code];
}

static NSString *NaverKRWSymbolForCode(NSString *code) {
    if ([code isEqualToString:@"KRW"]) {
        return nil;
    }
    return [NSString stringWithFormat:@"FX_%@KRW", code];
}

static double DecimalValue(id value) {
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return [value doubleValue];
    }
    if (![value isKindOfClass:NSString.class]) {
        return 0;
    }

    NSString *clean = [(NSString *)value stringByReplacingOccurrencesOfString:@"," withString:@""];
    return clean.doubleValue;
}

static NSArray<CurrencyItem *> *AllCurrencies(void) {
    static NSArray<CurrencyItem *> *items;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        items = @[
            [CurrencyItem itemWithCode:@"USD" name:@"U.S. Dollar" country:@"United States" flag:@"🇺🇸"],
            [CurrencyItem itemWithCode:@"KRW" name:@"Korean Won" country:@"South Korea" flag:@"🇰🇷"],
            [CurrencyItem itemWithCode:@"JPY" name:@"Japanese Yen" country:@"Japan" flag:@"🇯🇵"],
            [CurrencyItem itemWithCode:@"CNY" name:@"Chinese Yuan" country:@"China" flag:@"🇨🇳"],
            [CurrencyItem itemWithCode:@"EUR" name:@"Euro" country:@"Eurozone" flag:@"🇪🇺"],
            [CurrencyItem itemWithCode:@"GBP" name:@"British Pound" country:@"United Kingdom" flag:@"🇬🇧"],
            [CurrencyItem itemWithCode:@"AUD" name:@"Australian Dollar" country:@"Australia" flag:@"🇦🇺"],
            [CurrencyItem itemWithCode:@"CAD" name:@"Canadian Dollar" country:@"Canada" flag:@"🇨🇦"],
            [CurrencyItem itemWithCode:@"CHF" name:@"Swiss Franc" country:@"Switzerland" flag:@"🇨🇭"],
            [CurrencyItem itemWithCode:@"HKD" name:@"Hong Kong Dollar" country:@"Hong Kong" flag:@"🇭🇰"],
            [CurrencyItem itemWithCode:@"TWD" name:@"New Taiwan Dollar" country:@"Taiwan" flag:@"🇹🇼"],
            [CurrencyItem itemWithCode:@"SGD" name:@"Singapore Dollar" country:@"Singapore" flag:@"🇸🇬"],
            [CurrencyItem itemWithCode:@"THB" name:@"Thai Baht" country:@"Thailand" flag:@"🇹🇭"],
            [CurrencyItem itemWithCode:@"VND" name:@"Vietnamese Dong" country:@"Vietnam" flag:@"🇻🇳"],
            [CurrencyItem itemWithCode:@"PHP" name:@"Philippine Peso" country:@"Philippines" flag:@"🇵🇭"],
            [CurrencyItem itemWithCode:@"IDR" name:@"Indonesian Rupiah" country:@"Indonesia" flag:@"🇮🇩"],
            [CurrencyItem itemWithCode:@"MYR" name:@"Malaysian Ringgit" country:@"Malaysia" flag:@"🇲🇾"],
            [CurrencyItem itemWithCode:@"NZD" name:@"New Zealand Dollar" country:@"New Zealand" flag:@"🇳🇿"],
            [CurrencyItem itemWithCode:@"MXN" name:@"Mexican Peso" country:@"Mexico" flag:@"🇲🇽"],
            [CurrencyItem itemWithCode:@"BRL" name:@"Brazilian Real" country:@"Brazil" flag:@"🇧🇷"],
            [CurrencyItem itemWithCode:@"INR" name:@"Indian Rupee" country:@"India" flag:@"🇮🇳"]
        ];
    });
    return items;
}

static NSNumberFormatter *RateFormatter(void) {
    static NSNumberFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 3;
        formatter.minimumFractionDigits = 0;
        formatter.groupingSeparator = @",";
    });
    return formatter;
}

static NSNumberFormatter *CrossFormatter(void) {
    static NSNumberFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 4;
        formatter.minimumFractionDigits = 0;
    });
    return formatter;
}

static NSString *FormattedDate(NSDate *date) {
    if (!date) {
        return @"업데이트 대기 중";
    }
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"ko_KR"];
        formatter.dateFormat = @"M/d HH:mm";
    });
    return [formatter stringFromDate:date];
}

static NSColor *PanelColor(void) {
    return [NSColor colorWithCalibratedWhite:0.105 alpha:0.98];
}

static NSColor *CardColor(void) {
    return [NSColor colorWithCalibratedWhite:0.03 alpha:0.42];
}

static NSColor *SubtleColor(void) {
    return [NSColor colorWithCalibratedWhite:0.78 alpha:0.9];
}

static NSTextField *Label(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color ?: NSColor.labelColor;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

static NSView *RoundedView(NSColor *color, CGFloat radius) {
    NSView *view = [NSView new];
    view.wantsLayer = YES;
    view.layer.backgroundColor = color.CGColor;
    view.layer.cornerRadius = radius;
    view.layer.masksToBounds = YES;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    return view;
}

static void PanelLog(NSString *message) {
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSString *path = @"/private/tmp/CurrencyPanel.log";
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [data writeToFile:path atomically:YES];
        return;
    }

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    [handle seekToEndOfFile];
    [handle writeData:data];
    [handle closeFile];
}

static void InstallAppMenu(void) {
    NSMenu *mainMenu = [NSMenu new];

    NSMenuItem *appMenuItem = [NSMenuItem new];
    [mainMenu addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"CurrencyPanel"];
    NSString *quitTitle = @"Quit CurrencyPanel";
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:quitTitle
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    quitItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [appMenu addItem:quitItem];
    appMenuItem.submenu = appMenu;

    NSMenuItem *editMenuItem = [NSMenuItem new];
    [mainMenu addItem:editMenuItem];

    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    NSMenuItem *cutItem = [[NSMenuItem alloc] initWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    cutItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [editMenu addItem:cutItem];

    NSMenuItem *copyItem = [[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    copyItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [editMenu addItem:copyItem];

    NSMenuItem *pasteItem = [[NSMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    pasteItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [editMenu addItem:pasteItem];

    [editMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *selectAllItem = [[NSMenuItem alloc] initWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    selectAllItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [editMenu addItem:selectAllItem];
    editMenuItem.submenu = editMenu;

    NSApp.mainMenu = mainMenu;
}

static void InstallAppIcon(void) {
    NSImage *icon = [[NSImage alloc] initWithContentsOfFile:@"/private/tmp/local.codex.CurrencyPanel.AppIcon.icns"];
    if (icon) {
        NSApp.applicationIconImage = icon;
    }
}

@implementation RateStore
- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    _rates = @{};
    _previousRates = @{};
    _usdRates = @{};
    _usdAmount = [[NSUserDefaults standardUserDefaults] doubleForKey:USDAmountKey];
    if (_usdAmount <= 0) {
        _usdAmount = 1;
    }

    NSArray *savedCodes = [[NSUserDefaults standardUserDefaults] arrayForKey:SelectedCodesKey];
    if (savedCodes.count > 4) {
        _selectedCodes = [NSMutableSet setWithArray:savedCodes];
    } else {
        _selectedCodes = [NSMutableSet setWithArray:@[@"KRW", @"JPY", @"CNY", @"EUR", @"THB", @"VND", @"TWD", @"HKD", @"SGD", @"AUD", @"GBP", @"CAD"]];
    }

    NSDictionary *snapshot = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SnapshotKey];
    NSDictionary *snapshotRates = snapshot[@"rates"];
    if ([snapshotRates isKindOfClass:NSDictionary.class] && snapshotRates[@"USD"]) {
        _previousRates = snapshotRates;
    }

    return self;
}

- (NSArray<CurrencyItem *> *)selectedCurrencies {
    NSMutableArray *selected = [NSMutableArray array];
    for (CurrencyItem *item in AllCurrencies()) {
        if ([self.selectedCodes containsObject:item.code]) {
            [selected addObject:item];
        }
    }
    return selected;
}

- (void)start {
    [self refresh];
    [NSTimer scheduledTimerWithTimeInterval:RefreshInterval repeats:YES block:^(__unused NSTimer *timer) {
        [self refresh];
    }];
}

- (void)refresh {
    if (self.loading) {
        return;
    }
    self.loading = YES;
    self.errorMessage = nil;
    self.sourceName = @"환율 갱신 중";
    if (self.onChange) { self.onChange(); }
    [self fetchNaverRates];
}

- (void)fetchNaverRates {
    NSMutableDictionary<NSString *, NSNumber *> *newRates = [@{@"KRW": @1} mutableCopy];
    __block NSDate *latestDate = nil;
    dispatch_group_t group = dispatch_group_create();

    for (CurrencyItem *item in AllCurrencies()) {
        NSString *symbol = NaverKRWSymbolForCode(item.code);
        if (!symbol) {
            continue;
        }

        NSString *urlString = [NSString stringWithFormat:@"https://api.stock.naver.com/marketindex/exchange/%@", symbol];
        NSURL *url = [NSURL URLWithString:urlString];
        dispatch_group_enter(group);
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error) {
                NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
                NSError *jsonError = nil;
                NSDictionary *payload = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError] : nil;
                NSDictionary *info = payload[@"exchangeInfo"];
                double price = DecimalValue(info[@"calcPrice"] ?: info[@"closePrice"]);

                NSString *fullName = info[@"fullName"];
                if ([fullName isKindOfClass:NSString.class] && [fullName rangeOfString:@" 100"].location != NSNotFound) {
                    price /= 100.0;
                }

                if ([http isKindOfClass:NSHTTPURLResponse.class] && http.statusCode >= 200 && http.statusCode < 300 &&
                    !jsonError && price > 0) {
                    @synchronized (newRates) {
                        newRates[item.code] = @(price);
                    }

                    NSString *tradedAt = info[@"localTradedAt"];
                    if ([tradedAt isKindOfClass:NSString.class]) {
                        static NSISO8601DateFormatter *formatter;
                        static dispatch_once_t onceToken;
                        dispatch_once(&onceToken, ^{
                            formatter = [NSISO8601DateFormatter new];
                        });
                        NSDate *date = [formatter dateFromString:tradedAt];
                        if (date) {
                            @synchronized (self) {
                                if (!latestDate || [date compare:latestDate] == NSOrderedDescending) {
                                    latestDate = date;
                                }
                            }
                        }
                    }
                }
            }
            dispatch_group_leave(group);
        }];
        [task resume];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSNumber *usdKRW = newRates[@"USD"];
        if (usdKRW && newRates[@"JPY"] && newRates[@"CNY"]) {
            if (self.rates.count > 0) {
                self.previousRates = self.rates;
                [self persistSnapshot:self.rates];
            } else if (self.previousRates.count == 0) {
                self.previousRates = newRates;
                [self persistSnapshot:newRates];
            }

            NSMutableDictionary *derivedUSDRates = [@{@"USD": @1} mutableCopy];
            for (NSString *code in newRates) {
                NSNumber *krwPerUnit = newRates[code];
                if (krwPerUnit.doubleValue > 0) {
                    derivedUSDRates[code] = @(usdKRW.doubleValue / krwPerUnit.doubleValue);
                }
            }

            self.rates = newRates;
            self.usdRates = derivedUSDRates;
            self.lastUpdated = latestDate ?: [NSDate date];
            self.loading = NO;
            self.errorMessage = nil;
            self.sourceName = @"Naver 하나은행";
            if (self.onChange) { self.onChange(); }
        } else {
            self.loading = NO;
            self.errorMessage = @"Naver 환율 실패, Yahoo 재시도";
            self.sourceName = @"Yahoo 재시도 중";
            if (self.onChange) { self.onChange(); }
            [self fetchYahooRates];
        }
    });
}

- (void)fetchYahooRates {
    if (self.loading) {
        return;
    }
    self.loading = YES;
    self.errorMessage = nil;
    self.sourceName = @"Yahoo Finance";
    if (self.onChange) { self.onChange(); }

    NSMutableDictionary<NSString *, NSString *> *krwSymbols = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *usdSymbols = [NSMutableDictionary dictionary];
    for (CurrencyItem *item in AllCurrencies()) {
        NSString *krwSymbol = YahooKRWSymbolForCode(item.code);
        if (krwSymbol) {
            krwSymbols[item.code] = krwSymbol;
        }

        NSString *usdSymbol = YahooUSDSymbolForCode(item.code);
        if (usdSymbol) {
            usdSymbols[item.code] = usdSymbol;
        }
    }
    NSMutableDictionary<NSString *, NSNumber *> *krwQuotes = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSNumber *> *usdQuotes = [NSMutableDictionary dictionary];
    __block NSDate *latestDate = nil;

    NSMutableDictionary<NSString *, NSString *> *krwCodeBySymbol = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *usdCodeBySymbol = [NSMutableDictionary dictionary];
    NSMutableOrderedSet<NSString *> *symbols = [NSMutableOrderedSet orderedSet];
    [krwSymbols enumerateKeysAndObjectsUsingBlock:^(NSString *code, NSString *symbol, __unused BOOL *stop) {
        krwCodeBySymbol[symbol] = code;
        [symbols addObject:symbol];
    }];
    [usdSymbols enumerateKeysAndObjectsUsingBlock:^(NSString *code, NSString *symbol, __unused BOOL *stop) {
        usdCodeBySymbol[symbol] = code;
        [symbols addObject:symbol];
    }];

    NSString *joinedSymbols = [[symbols array] componentsJoinedByString:@","];
    NSString *encodedSymbols = [joinedSymbols stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *urlString = [NSString stringWithFormat:@"https://query1.finance.yahoo.com/v7/finance/quote?symbols=%@", encodedSymbols];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL hadError = error != nil;
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            NSError *jsonError = nil;
            NSDictionary *payload = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError] : nil;
            NSArray *results = payload[@"quoteResponse"][@"result"];
            if (![http isKindOfClass:NSHTTPURLResponse.class] || http.statusCode < 200 || http.statusCode >= 300 ||
                jsonError || ![results isKindOfClass:NSArray.class]) {
                self.loading = NO;
                self.errorMessage = hadError ? @"Yahoo 환율 실패, 예비 소스 전환" : @"Yahoo 환율 데이터 부족";
                if (self.onChange) { self.onChange(); }
                [self fetchFallbackRates];
                return;
            }

            for (NSDictionary *quote in results) {
                if (![quote isKindOfClass:NSDictionary.class]) {
                    continue;
                }

                NSString *symbol = quote[@"symbol"];
                NSNumber *price = quote[@"regularMarketPrice"] ?: quote[@"bid"] ?: quote[@"ask"] ?: quote[@"regularMarketPreviousClose"];
                NSNumber *timestamp = quote[@"regularMarketTime"];
                if (![symbol isKindOfClass:NSString.class] || ![price respondsToSelector:@selector(doubleValue)] || price.doubleValue <= 0) {
                    continue;
                }

                NSString *krwCode = krwCodeBySymbol[symbol];
                if (krwCode) {
                    krwQuotes[krwCode] = price;
                }

                NSString *usdCode = usdCodeBySymbol[symbol];
                if (usdCode) {
                    usdQuotes[usdCode] = price;
                }

                if ([timestamp respondsToSelector:@selector(doubleValue)]) {
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp.doubleValue];
                    if (!latestDate || [date compare:latestDate] == NSOrderedDescending) {
                        latestDate = date;
                    }
                }
            }

            NSMutableDictionary<NSString *, NSNumber *> *newRates = [NSMutableDictionary dictionary];
            NSMutableDictionary<NSString *, NSNumber *> *derivedUSDRates = [@{@"USD": @1} mutableCopy];
            newRates[@"KRW"] = @1;

        NSNumber *baseUSDKRW = krwQuotes[@"USD"] ?: usdQuotes[@"KRW"];
        if (baseUSDKRW) {
            newRates[@"USD"] = baseUSDKRW;
            derivedUSDRates[@"KRW"] = baseUSDKRW;
        }

        for (CurrencyItem *item in AllCurrencies()) {
            NSString *code = item.code;
            if ([code isEqualToString:@"USD"] || [code isEqualToString:@"KRW"]) {
                continue;
            }

            NSNumber *krwPerUnit = krwQuotes[code];
            NSNumber *unitsPerUSD = usdQuotes[code];
            if (!krwPerUnit && baseUSDKRW && unitsPerUSD.doubleValue > 0) {
                krwPerUnit = @(baseUSDKRW.doubleValue / unitsPerUSD.doubleValue);
            }
            if (krwPerUnit.doubleValue > 0) {
                newRates[code] = krwPerUnit;
            }
            if (unitsPerUSD.doubleValue > 0) {
                derivedUSDRates[code] = unitsPerUSD;
            } else if (baseUSDKRW && krwPerUnit.doubleValue > 0) {
                derivedUSDRates[code] = @(baseUSDKRW.doubleValue / krwPerUnit.doubleValue);
            }
        }

        if (baseUSDKRW && newRates[@"JPY"] && newRates[@"CNY"]) {
            if (self.rates.count > 0) {
                self.previousRates = self.rates;
                [self persistSnapshot:self.rates];
            } else if (self.previousRates.count == 0) {
                self.previousRates = newRates;
                [self persistSnapshot:newRates];
            }

            self.rates = newRates;
            self.usdRates = derivedUSDRates;
            self.lastUpdated = latestDate ?: [NSDate date];
            self.loading = NO;
            self.errorMessage = nil;
            self.sourceName = @"Yahoo Finance";
            if (self.onChange) { self.onChange(); }
        } else {
            self.loading = NO;
            self.errorMessage = @"Yahoo 환율 데이터 부족";
            if (self.onChange) { self.onChange(); }
            [self fetchFallbackRates];
        }
        });
    }];
    [task resume];
}

- (void)fetchFallbackRates {
    self.loading = YES;
    NSURL *url = [NSURL URLWithString:@"https://open.er-api.com/v6/latest/USD"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.loading = NO;
            if (error) {
                self.errorMessage = error.localizedDescription;
                if (self.onChange) { self.onChange(); }
                return;
            }

            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            NSError *jsonError = nil;
            NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            NSDictionary *usdRates = payload[@"rates"];
            NSNumber *krw = usdRates[@"KRW"];
            NSNumber *jpy = usdRates[@"JPY"];
            NSNumber *cny = usdRates[@"CNY"];

            if (![http isKindOfClass:NSHTTPURLResponse.class] || http.statusCode < 200 || http.statusCode >= 300 ||
                jsonError || !krw || !jpy || !cny || jpy.doubleValue <= 0 || cny.doubleValue <= 0) {
                self.errorMessage = @"환율 데이터를 읽을 수 없습니다.";
                if (self.onChange) { self.onChange(); }
                return;
            }

            NSMutableDictionary *fallback = [@{@"USD": krw, @"KRW": @1} mutableCopy];
            for (CurrencyItem *item in AllCurrencies()) {
                if ([item.code isEqualToString:@"USD"] || [item.code isEqualToString:@"KRW"]) {
                    continue;
                }

                NSNumber *usdRate = usdRates[item.code];
                if (usdRate.doubleValue > 0) {
                    fallback[item.code] = @(krw.doubleValue / usdRate.doubleValue);
                }
            }

            if (self.rates.count > 0) {
                self.previousRates = self.rates;
                [self persistSnapshot:self.rates];
            } else if (self.previousRates.count == 0) {
                self.previousRates = fallback;
                [self persistSnapshot:fallback];
            }

            self.rates = fallback;
            self.usdRates = usdRates;
            NSNumber *time = payload[@"time_last_update_unix"];
            self.lastUpdated = [time respondsToSelector:@selector(doubleValue)] ? [NSDate dateWithTimeIntervalSince1970:time.doubleValue] : [NSDate date];
            self.errorMessage = @"예비 소스 사용 중";
            self.sourceName = @"ExchangeRate-API";
            if (self.onChange) { self.onChange(); }
        });
    }];
    [task resume];
}

- (void)toggleCurrency:(CurrencyItem *)currency {
    if ([self.selectedCodes containsObject:currency.code]) {
        [self.selectedCodes removeObject:currency.code];
    } else {
        [self.selectedCodes addObject:currency.code];
    }

    if (self.selectedCodes.count == 0) {
        [self.selectedCodes addObject:@"KRW"];
    }

    NSArray *codes = [[self.selectedCodes allObjects] sortedArrayUsingSelector:@selector(compare:)];
    [[NSUserDefaults standardUserDefaults] setObject:codes forKey:SelectedCodesKey];
    if (self.onChange) { self.onChange(); }
}

- (void)setUsdAmount:(double)usdAmount {
    _usdAmount = usdAmount;
    [[NSUserDefaults standardUserDefaults] setDouble:usdAmount forKey:USDAmountKey];
}

- (double)convertedValueForCode:(NSString *)code available:(BOOL *)available {
    BOOL ok = NO;
    double rate = [self usdRateForCode:code available:&ok];
    if (!ok) {
        if (available) { *available = NO; }
        return 0;
    }
    if (available) { *available = YES; }
    return rate * self.usdAmount;
}

- (double)usdRateForCode:(NSString *)code available:(BOOL *)available {
    if ([code isEqualToString:@"USD"]) {
        if (available) { *available = YES; }
        return 1;
    }

    NSNumber *rate = self.usdRates[code];
    if (!rate && [code isEqualToString:@"KRW"]) {
        rate = self.rates[@"USD"];
    }

    if (!rate && ([code isEqualToString:@"JPY"] || [code isEqualToString:@"CNY"])) {
        NSNumber *usdKRW = self.rates[@"USD"];
        NSNumber *targetKRW = self.rates[code];
        if (usdKRW && targetKRW && targetKRW.doubleValue > 0) {
            rate = @(usdKRW.doubleValue / targetKRW.doubleValue);
        }
    }

    if (!rate || rate.doubleValue <= 0) {
        if (available) { *available = NO; }
        return 0;
    }

    if (available) { *available = YES; }
    return rate.doubleValue;
}

- (double)krwValueForCode:(NSString *)code unit:(double)unit available:(BOOL *)available {
    NSNumber *rate = self.rates[code];
    if (!rate) {
        if (available) { *available = NO; }
        return 0;
    }
    if (available) { *available = YES; }
    return rate.doubleValue * unit;
}

- (double)deltaPercentForCode:(NSString *)code available:(BOOL *)available {
    NSNumber *now = self.rates[code];
    NSNumber *before = self.previousRates[code];
    if (!now || !before || before.doubleValue <= 0 || now.doubleValue == before.doubleValue) {
        if (available) { *available = NO; }
        return 0;
    }
    if (available) { *available = YES; }
    return ((now.doubleValue - before.doubleValue) / before.doubleValue) * 100.0;
}

- (double)krwCrossForCode:(NSString *)code available:(BOOL *)available {
    NSNumber *krw = self.rates[@"KRW"];
    NSNumber *target = self.rates[code];
    if (!krw || !target || krw.doubleValue <= 0) {
        if (available) { *available = NO; }
        return 0;
    }
    if (available) { *available = YES; }
    return 1000.0 * target.doubleValue / krw.doubleValue;
}

- (double)krwCrossDeltaForCode:(NSString *)code available:(BOOL *)available {
    NSNumber *nowKRW = self.rates[@"KRW"];
    NSNumber *nowTarget = self.rates[code];
    NSNumber *oldKRW = self.previousRates[@"KRW"];
    NSNumber *oldTarget = self.previousRates[code];

    if (!nowKRW || !nowTarget || !oldKRW || !oldTarget || nowKRW.doubleValue <= 0 || oldKRW.doubleValue <= 0) {
        if (available) { *available = NO; }
        return 0;
    }

    double now = nowTarget.doubleValue / nowKRW.doubleValue;
    double old = oldTarget.doubleValue / oldKRW.doubleValue;
    if (old <= 0 || now == old) {
        if (available) { *available = NO; }
        return 0;
    }

    if (available) { *available = YES; }
    return ((now - old) / old) * 100.0;
}

- (void)persistSnapshot:(NSDictionary *)rates {
    [[NSUserDefaults standardUserDefaults] setObject:@{
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"rates": rates
    } forKey:SnapshotKey];
}
@end

@interface CurrencyWindowController : NSWindowController <NSTextFieldDelegate, NSWindowDelegate>
@property (nonatomic, strong) RateStore *store;
@property (nonatomic, strong) NSStackView *rootStack;
@property (nonatomic, strong) NSStackView *listStack;
@property (nonatomic, strong) NSTextField *amountField;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSTextField *> *calculatorFields;
@property (nonatomic, strong) NSMutableArray<NSString *> *calculatorCodes;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSTextField *lastUpdatedLabel;
@property (nonatomic) BOOL updatingCalculatorFields;
@end

@implementation CurrencyWindowController
- (instancetype)initWithStore:(RateStore *)store {
    PanelLog(@"CurrencyWindowController init");
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 340, 394)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskFullSizeContentView
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (!self) { return nil; }

    _store = store;
    _calculatorFields = [NSMutableDictionary dictionary];
    NSArray *savedCalculatorCodes = [[NSUserDefaults standardUserDefaults] arrayForKey:CalculatorCodesKey];
    if (savedCalculatorCodes.count == 7) {
        _calculatorCodes = [savedCalculatorCodes mutableCopy];
    } else {
        _calculatorCodes = [DefaultCalculatorCodes() mutableCopy];
    }
    __weak typeof(self) weakSelf = self;
    _store.onChange = ^{
        [weakSelf rebuild];
    };

    [self configureWindow];
    [self buildRoot];
    [self rebuild];
    PanelLog(@"CurrencyWindowController ready");
    return self;
}

- (void)configureWindow {
    NSWindow *window = self.window;
    window.title = @"CurrencyPanel";
    window.delegate = self;
    window.level = NSFloatingWindowLevel;
    window.releasedWhenClosed = NO;
    window.movableByWindowBackground = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.titlebarAppearsTransparent = YES;
    window.backgroundColor = NSColor.clearColor;
    window.opaque = NO;
    window.collectionBehavior = NSWindowCollectionBehaviorManaged | NSWindowCollectionBehaviorFullScreenAuxiliary;
    [window standardWindowButton:NSWindowMiniaturizeButton].hidden = YES;
    [window standardWindowButton:NSWindowZoomButton].hidden = YES;
    NSScreen *screen = NSScreen.mainScreen;
    for (NSScreen *candidate in NSScreen.screens) {
        NSRect frame = candidate.visibleFrame;
        if (NSMinX(frame) >= 0 && NSMinY(frame) >= 0) {
            screen = candidate;
            break;
        }
    }
    if (screen) {
        NSRect visible = screen.visibleFrame;
        CGFloat width = window.frame.size.width;
        CGFloat height = window.frame.size.height;
        CGFloat x = NSMinX(visible) + 22;
        CGFloat y = NSMaxY(visible) - height - 42;
        NSRect frame = NSMakeRect(x, y, width, height);
        [window setFrame:frame display:YES];
    } else {
        [window center];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    PanelLog(@"windowWillClose terminate");
    [NSApp terminate:nil];
}

- (void)buildRoot {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 340, 394)];
    container.wantsLayer = YES;
    container.layer.backgroundColor = PanelColor().CGColor;
    container.layer.cornerRadius = 18;
    container.layer.masksToBounds = YES;
    container.layer.borderColor = [NSColor colorWithCalibratedWhite:1 alpha:0.13].CGColor;
    container.layer.borderWidth = 1;
    container.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.window.contentView = container;

    self.rootStack = [NSStackView stackViewWithViews:@[]];
    self.rootStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.rootStack.spacing = 6;
    self.rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.rootStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.rootStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:10],
        [self.rootStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-10],
        [self.rootStack.topAnchor constraintEqualToAnchor:container.topAnchor constant:10],
        [self.rootStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-10]
    ]];
}

- (void)rebuild {
    [self.rootStack.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.rootStack addArrangedSubview:[self headerView]];
    [self.rootStack addArrangedSubview:[self rateBoardView]];
    [self.rootStack addArrangedSubview:[self calculatorView]];
}

- (NSView *)headerView {
    NSStackView *header = [NSStackView stackViewWithViews:@[]];
    header.orientation = NSUserInterfaceLayoutOrientationVertical;
    header.spacing = 3;
    header.translatesAutoresizingMaskIntoConstraints = NO;

    NSStackView *row = [NSStackView stackViewWithViews:@[]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8;

    NSStackView *labels = [NSStackView stackViewWithViews:@[]];
    labels.orientation = NSUserInterfaceLayoutOrientationVertical;
    labels.spacing = 2;
    [labels addArrangedSubview:Label(@"환율", 18, NSFontWeightBold, NSColor.labelColor)];
    NSString *sourceText = self.store.sourceName.length > 0 ? self.store.sourceName : @"소스 대기";
    [labels addArrangedSubview:Label([NSString stringWithFormat:@"5분 자동 갱신 · %@", sourceText], 11, NSFontWeightSemibold, SubtleColor())];
    [row addArrangedSubview:labels];

    NSView *spacer = [NSView new];
    [row addArrangedSubview:spacer];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSButton *refresh = [self iconButton:@"arrow.clockwise" action:@selector(refreshTapped:)];
    refresh.toolTip = @"환율 새로고침";
    [row addArrangedSubview:refresh];

    [header addArrangedSubview:row];

    if (self.store.errorMessage || self.store.loading) {
        NSStackView *statusRow = [NSStackView stackViewWithViews:@[]];
        statusRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        statusRow.alignment = NSLayoutAttributeCenterY;
        statusRow.spacing = 6;

        NSView *dot = RoundedView(self.store.errorMessage ? NSColor.systemRedColor : NSColor.systemYellowColor, 4);
        [dot.widthAnchor constraintEqualToConstant:8].active = YES;
        [dot.heightAnchor constraintEqualToConstant:8].active = YES;
        [statusRow addArrangedSubview:dot];

        self.statusLabel = Label(self.store.errorMessage ?: @"환율 갱신 중", 10, NSFontWeightMedium, self.store.errorMessage ? NSColor.systemRedColor : SubtleColor());
        [statusRow addArrangedSubview:self.statusLabel];
        [header addArrangedSubview:statusRow];
    }

    return header;
}

- (NSView *)rateBoardView {
    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.spacing = 6;
    [stack addArrangedSubview:[self keyRateRowForCode:@"USD" title:@"달러" unitLabel:@"1달러" multiplier:1 flag:@"🇺🇸"]];
    [stack addArrangedSubview:[self keyRateRowForCode:@"JPY" title:@"엔" unitLabel:@"100엔" multiplier:100 flag:@"🇯🇵"]];
    [stack addArrangedSubview:[self keyRateRowForCode:@"CNY" title:@"위안" unitLabel:@"1위안" multiplier:1 flag:@"🇨🇳"]];
    return stack;
}

- (NSView *)keyRateRowForCode:(NSString *)code title:(NSString *)title unitLabel:(NSString *)unitLabel multiplier:(double)multiplier flag:(NSString *)flag {
    NSView *card = RoundedView(CardColor(), 8);
    [card.heightAnchor constraintEqualToConstant:62].active = YES;
    [card.widthAnchor constraintGreaterThanOrEqualToConstant:98].active = YES;

    NSStackView *column = [NSStackView stackViewWithViews:@[]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeft;
    column.spacing = 1;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:column];

    [NSLayoutConstraint activateConstraints:@[
        [column.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8],
        [column.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8],
        [column.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];

    NSStackView *top = [NSStackView stackViewWithViews:@[]];
    top.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    top.alignment = NSLayoutAttributeCenterY;
    top.spacing = 4;
    [top addArrangedSubview:Label(flag, 15, NSFontWeightRegular, NSColor.labelColor)];
    [top addArrangedSubview:Label(unitLabel, 11, NSFontWeightSemibold, SubtleColor())];
    [column addArrangedSubview:top];

    BOOL ok = NO;
    double krw = [self.store krwValueForCode:code unit:multiplier available:&ok];
    NSString *valueText = ok ? [NSString stringWithFormat:@"%@원", [RateFormatter() stringFromNumber:@(krw)]] : @"--";
    NSTextField *value = Label(valueText, 17, NSFontWeightSemibold, NSColor.labelColor);
    value.font = [NSFont monospacedDigitSystemFontOfSize:17 weight:NSFontWeightSemibold];
    value.alignment = NSTextAlignmentLeft;
    [column addArrangedSubview:value];

    BOOL deltaOK = NO;
    double delta = [self.store deltaPercentForCode:code available:&deltaOK];
    [column addArrangedSubview:[self deltaLabel:delta available:deltaOK compact:YES]];

    return card;
}

- (NSView *)calculatorView {
    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 4;
    self.calculatorFields = [NSMutableDictionary dictionary];

    [stack addArrangedSubview:Label(@"계산", 14, NSFontWeightBold, NSColor.labelColor)];

    for (NSUInteger index = 0; index < self.calculatorCodes.count; index++) {
        [stack addArrangedSubview:[self calculatorRowForCode:self.calculatorCodes[index] index:index]];
    }
    return stack;
}

- (NSView *)calculatorRowForCode:(NSString *)code index:(NSUInteger)index {
    NSView *card = RoundedView(CardColor(), 7);
    [card.heightAnchor constraintEqualToConstant:34].active = YES;

    NSStackView *row = [NSStackView stackViewWithViews:@[]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:row];

    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8],
        [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8],
        [row.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];

    CurrencyItem *matched = nil;
    for (CurrencyItem *item in AllCurrencies()) {
        if ([item.code isEqualToString:code]) {
            matched = item;
            break;
        }
    }

    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    popup.tag = (NSInteger)index;
    popup.target = self;
    popup.action = @selector(calculatorCurrencyChanged:);
    popup.bezelStyle = NSBezelStyleTexturedRounded;
    popup.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    popup.translatesAutoresizingMaskIntoConstraints = NO;
    [popup.widthAnchor constraintEqualToConstant:104].active = YES;
    for (CurrencyItem *item in AllCurrencies()) {
        NSString *title = [NSString stringWithFormat:@"%@ %@", item.flag, item.code];
        [popup addItemWithTitle:title];
        popup.lastItem.representedObject = item.code;
        if ([item.code isEqualToString:code]) {
            [popup selectItem:popup.lastItem];
        }
    }
    [row addArrangedSubview:popup];

    NSTextField *name = Label(matched.name ?: code, 11, NSFontWeightSemibold, SubtleColor());
    [row addArrangedSubview:name];

    NSView *spacer = [NSView new];
    [row addArrangedSubview:spacer];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.identifier = code;
    field.tag = (NSInteger)index;
    field.font = [NSFont monospacedDigitSystemFontOfSize:18 weight:NSFontWeightSemibold];
    field.textColor = NSColor.labelColor;
    field.alignment = NSTextAlignmentRight;
    field.bordered = NO;
    field.drawsBackground = YES;
    field.backgroundColor = [NSColor colorWithCalibratedWhite:1 alpha:0.07];
    field.delegate = self;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.cell.lineBreakMode = NSLineBreakByClipping;
    field.cell.usesSingleLineMode = YES;
    [field.widthAnchor constraintEqualToConstant:112].active = YES;
    [row addArrangedSubview:field];
    self.calculatorFields[code] = field;

    [self updateCalculatorField:field code:code];
    return card;
}

- (NSString *)amountString {
    double amount = self.store.usdAmount;
    if (floor(amount) == amount) {
        return [NSString stringWithFormat:@"%.0f", amount];
    }
    return [NSString stringWithFormat:@"%g", amount];
}

- (NSString *)calculatorStringForValue:(double)value code:(NSString *)code {
    NSInteger digits = 3;
    if ([code isEqualToString:@"KRW"] || [code isEqualToString:@"JPY"] || [code isEqualToString:@"VND"]) {
        digits = 0;
    } else if (value >= 1000) {
        digits = 1;
    }

    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.maximumFractionDigits = digits;
    formatter.minimumFractionDigits = 0;
    formatter.groupingSeparator = @",";
    return [formatter stringFromNumber:@(value)] ?: @"";
}

- (void)updateCalculatorField:(NSTextField *)field code:(NSString *)code {
    BOOL ok = NO;
    double value = [self.store convertedValueForCode:code available:&ok];
    NSString *text = ok ? [self calculatorStringForValue:value code:code] : @"";
    field.stringValue = text;
    [self applyCalculatorFontToField:field valueString:text];
}

- (void)applyCalculatorFontToField:(NSTextField *)field valueString:(NSString *)valueString {
    CGFloat size = 18;
    CGFloat availableWidth = 104;
    while (size > 12) {
        NSFont *font = [NSFont monospacedDigitSystemFontOfSize:size weight:NSFontWeightSemibold];
        CGFloat width = [valueString sizeWithAttributes:@{NSFontAttributeName: font}].width;
        if (width <= availableWidth) {
            field.font = font;
            return;
        }
        size -= 1;
    }
    field.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightSemibold];
}

- (void)updateCalculatorFieldsExcept:(NSString *)editedCode {
    self.updatingCalculatorFields = YES;
    for (NSString *code in self.calculatorCodes) {
        if ([code isEqualToString:editedCode]) {
            continue;
        }
        NSTextField *field = self.calculatorFields[code];
        if (field) {
            [self updateCalculatorField:field code:code];
        }
    }
    self.updatingCalculatorFields = NO;
}

- (void)calculatorCurrencyChanged:(NSPopUpButton *)sender {
    if (sender.tag < 0 || sender.tag >= (NSInteger)self.calculatorCodes.count) {
        return;
    }

    NSString *newCode = sender.selectedItem.representedObject;
    if (newCode.length == 0) {
        return;
    }

    self.calculatorCodes[(NSUInteger)sender.tag] = newCode;
    [[NSUserDefaults standardUserDefaults] setObject:self.calculatorCodes forKey:CalculatorCodesKey];
    [self rebuild];
}

- (NSView *)crossView {
    NSStackView *row = [NSStackView stackViewWithViews:@[]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.spacing = 10;
    [row addArrangedSubview:[self crossPillForCode:@"JPY" label:@"1,000원 -> 엔"]];
    [row addArrangedSubview:[self crossPillForCode:@"CNY" label:@"1,000원 -> 위안"]];
    return row;
}

- (NSView *)crossPillForCode:(NSString *)code label:(NSString *)label {
    NSView *card = RoundedView([NSColor colorWithCalibratedWhite:1 alpha:0.06], 8);
    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 6;
    stack.edgeInsets = NSEdgeInsetsMake(12, 12, 12, 12);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor]
    ]];

    [stack addArrangedSubview:Label(label, 12, NSFontWeightSemibold, SubtleColor())];

    BOOL ok = NO;
    double value = [self.store krwCrossForCode:code available:&ok];
    NSString *text = ok ? [CrossFormatter() stringFromNumber:@(value)] : @"--";
    NSTextField *valueLabel = Label(text, 20, NSFontWeightBold, NSColor.labelColor);
    [stack addArrangedSubview:valueLabel];

    BOOL deltaOK = NO;
    double delta = [self.store krwCrossDeltaForCode:code available:&deltaOK];
    [stack addArrangedSubview:[self deltaLabel:delta available:deltaOK compact:YES]];
    [card.widthAnchor constraintGreaterThanOrEqualToConstant:210].active = YES;
    return card;
}

- (NSView *)scrollListView {
    NSScrollView *scroll = [NSScrollView new];
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll.heightAnchor constraintEqualToConstant:208].active = YES;

    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 9;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    for (CurrencyItem *currency in [self.store selectedCurrencies]) {
        [stack addArrangedSubview:[self rowForCurrency:currency]];
    }

    NSView *document = [NSView new];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    [document addSubview:stack];
    scroll.documentView = document;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:document.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:document.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:document.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-16]
    ]];

    return scroll;
}

- (NSView *)rowForCurrency:(CurrencyItem *)currency {
    NSView *card = RoundedView(CardColor(), 8);
    [card.heightAnchor constraintEqualToConstant:42].active = YES;
    NSStackView *row = [NSStackView stackViewWithViews:@[]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:row];

    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:9],
        [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-9],
        [row.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];

    NSTextField *flag = Label(currency.flag, 18, NSFontWeightRegular, NSColor.labelColor);
    flag.alignment = NSTextAlignmentCenter;
    [flag.widthAnchor constraintEqualToConstant:26].active = YES;
    [row addArrangedSubview:flag];

    NSStackView *names = [NSStackView stackViewWithViews:@[]];
    names.orientation = NSUserInterfaceLayoutOrientationVertical;
    names.spacing = 0;
    [names addArrangedSubview:Label(currency.code, 14, NSFontWeightBold, NSColor.labelColor)];
    [names addArrangedSubview:Label(currency.name, 10, NSFontWeightSemibold, SubtleColor())];
    [row addArrangedSubview:names];

    NSView *spacer = [NSView new];
    [row addArrangedSubview:spacer];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *values = [NSStackView stackViewWithViews:@[]];
    values.orientation = NSUserInterfaceLayoutOrientationVertical;
    values.alignment = NSLayoutAttributeRight;
    values.spacing = 0;

    BOOL ok = NO;
    double converted = [self.store convertedValueForCode:currency.code available:&ok];
    NSTextField *valueLabel = Label(ok ? [RateFormatter() stringFromNumber:@(converted)] : @"--", 18, NSFontWeightSemibold, NSColor.labelColor);
    valueLabel.font = [NSFont monospacedDigitSystemFontOfSize:18 weight:NSFontWeightSemibold];
    valueLabel.alignment = NSTextAlignmentRight;
    [values addArrangedSubview:valueLabel];
    [row addArrangedSubview:values];

    return card;
}

- (NSView *)footerView {
    NSStackView *footer = [NSStackView stackViewWithViews:@[]];
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.alignment = NSLayoutAttributeCenterY;
    footer.spacing = 12;

    self.lastUpdatedLabel = Label(FormattedDate(self.store.lastUpdated), 11, NSFontWeightSemibold, SubtleColor());
    [footer addArrangedSubview:self.lastUpdatedLabel];

    NSView *spacer = [NSView new];
    [footer addArrangedSubview:spacer];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    [footer addArrangedSubview:Label(@"Yahoo Finance", 11, NSFontWeightSemibold, [NSColor colorWithCalibratedWhite:0.7 alpha:0.55])];
    return footer;
}

- (NSButton *)iconButton:(NSString *)symbol action:(SEL)action {
    NSButton *button = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] target:self action:action];
    button.bezelStyle = NSBezelStyleRegularSquare;
    button.bordered = YES;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button.widthAnchor constraintEqualToConstant:30].active = YES;
    [button.heightAnchor constraintEqualToConstant:30].active = YES;
    return button;
}

- (NSView *)flagBadge:(NSString *)flag {
    NSView *badge = RoundedView([NSColor colorWithCalibratedWhite:1 alpha:0.95], 5);
    [badge.widthAnchor constraintEqualToConstant:58].active = YES;
    [badge.heightAnchor constraintEqualToConstant:42].active = YES;

    NSTextField *label = Label(flag, 31, NSFontWeightRegular, NSColor.labelColor);
    label.alignment = NSTextAlignmentCenter;
    [badge addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor]
    ]];
    return badge;
}

- (NSTextField *)deltaLabel:(double)delta available:(BOOL)available compact:(BOOL)compact {
    NSString *text = @"new";
    NSColor *color = [NSColor colorWithCalibratedWhite:0.7 alpha:0.75];
    if (available) {
        NSString *sign = delta > 0 ? @"+" : @"";
        text = [NSString stringWithFormat:@"%@%.2f%%", sign, delta];
        color = delta >= 0 ? NSColor.systemGreenColor : NSColor.systemRedColor;
    }
    NSTextField *label = Label(text, compact ? 11 : 12, NSFontWeightBold, color);
    label.alignment = compact ? NSTextAlignmentLeft : NSTextAlignmentRight;
    return label;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if (self.updatingCalculatorFields) {
        return;
    }

    NSTextField *field = notification.object;
    NSString *code = field.identifier;
    if (code.length == 0 || ![self.calculatorCodes containsObject:code]) {
        return;
    }

    NSString *raw = [[field.stringValue stringByReplacingOccurrencesOfString:@"," withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""];
    double amount = raw.doubleValue;
    BOOL ok = NO;
    double rate = [self.store usdRateForCode:code available:&ok];
    if (ok && rate > 0 && amount >= 0) {
        self.store.usdAmount = amount / rate;
        [self applyCalculatorFontToField:field valueString:field.stringValue];
        [self updateCalculatorFieldsExcept:code];
    }
}

- (void)controlTextDidBeginEditing:(NSNotification *)notification {
    NSTextField *field = notification.object;
    NSText *editor = field.currentEditor;
    if (editor) {
        [editor setSelectedRange:NSMakeRange(0, field.stringValue.length)];
    } else {
        [field selectText:nil];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *field = notification.object;
    NSString *code = field.identifier;
    if (code.length > 0 && [self.calculatorCodes containsObject:code]) {
        [self updateCalculatorField:field code:code];
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertTab:)) {
        [self focusCalculatorFieldFromIndex:control.tag direction:1];
        return YES;
    }
    if (commandSelector == @selector(insertBacktab:)) {
        [self focusCalculatorFieldFromIndex:control.tag direction:-1];
        return YES;
    }
    if (commandSelector == @selector(cancelOperation:)) {
        NSTextField *field = [control isKindOfClass:NSTextField.class] ? (NSTextField *)control : nil;
        NSString *code = field.identifier;
        if (code.length > 0 && [self.calculatorCodes containsObject:code]) {
            [self updateCalculatorField:field code:code];
        }
        [self.window makeFirstResponder:nil];
        return YES;
    }
    return NO;
}

- (void)focusCalculatorFieldFromIndex:(NSInteger)index direction:(NSInteger)direction {
    NSInteger count = (NSInteger)self.calculatorCodes.count;
    if (count <= 0) {
        return;
    }

    NSInteger next = (index + direction + count) % count;
    NSString *code = self.calculatorCodes[(NSUInteger)next];
    NSTextField *field = self.calculatorFields[code];
    if (field) {
        [self.window makeFirstResponder:field];
        [field selectText:nil];
    }
}

- (void)refreshTapped:(id)sender {
    [self.store refresh];
}

- (void)pickerTapped:(id)sender {
    NSWindow *panel = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 390, 560)
                                                 styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
    panel.title = @"통화 선택";
    panel.backgroundColor = PanelColor();

    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 8;
    stack.edgeInsets = NSEdgeInsetsMake(16, 16, 16, 16);
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    NSScrollView *scroll = [NSScrollView new];
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;

    NSStackView *list = [NSStackView stackViewWithViews:@[]];
    list.orientation = NSUserInterfaceLayoutOrientationVertical;
    list.spacing = 6;
    list.translatesAutoresizingMaskIntoConstraints = NO;

    for (CurrencyItem *currency in AllCurrencies()) {
        NSButton *checkbox = [NSButton checkboxWithTitle:[NSString stringWithFormat:@"%@  %@ · %@", currency.flag, currency.name, currency.code]
                                                  target:self
                                                  action:@selector(currencyCheckboxTapped:)];
        checkbox.identifier = currency.code;
        checkbox.state = [self.store.selectedCodes containsObject:currency.code] ? NSControlStateValueOn : NSControlStateValueOff;
        checkbox.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
        [list addArrangedSubview:checkbox];
    }

    NSView *document = [NSView new];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    [document addSubview:list];
    scroll.documentView = document;
    [NSLayoutConstraint activateConstraints:@[
        [list.leadingAnchor constraintEqualToAnchor:document.leadingAnchor],
        [list.trailingAnchor constraintEqualToAnchor:document.trailingAnchor],
        [list.topAnchor constraintEqualToAnchor:document.topAnchor],
        [list.bottomAnchor constraintEqualToAnchor:document.bottomAnchor],
        [list.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-16]
    ]];
    [stack addArrangedSubview:scroll];

    NSButton *done = [NSButton buttonWithTitle:@"완료" target:panel action:@selector(close)];
    done.bezelStyle = NSBezelStyleRounded;
    [stack addArrangedSubview:done];

    panel.contentView = stack;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor]
    ]];

    [self.window beginSheet:panel completionHandler:nil];
}

- (void)currencyCheckboxTapped:(NSButton *)sender {
    for (CurrencyItem *currency in AllCurrencies()) {
        if ([currency.code isEqualToString:sender.identifier]) {
            [self.store toggleCurrency:currency];
            return;
        }
    }
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) RateStore *store;
@property (nonatomic, strong) CurrencyWindowController *windowController;
@property (nonatomic, strong) id keyMonitor;
@property (nonatomic) BOOL started;
- (void)startIfNeeded;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    InstallAppIcon();
    [self startIfNeeded];
}

- (void)startIfNeeded {
    if (self.started) {
        return;
    }
    PanelLog(@"AppDelegate startIfNeeded");
    self.started = YES;
    self.store = [RateStore new];
    self.windowController = [[CurrencyWindowController alloc] initWithStore:self.store];
    [self.windowController showWindow:nil];
    [self.windowController.window makeKeyAndOrderFront:nil];
    [self.windowController.window orderFrontRegardless];
    PanelLog([NSString stringWithFormat:@"window visible=%@ frame=%@", self.windowController.window.isVisible ? @"YES" : @"NO", NSStringFromRect(self.windowController.window.frame)]);
    self.keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        BOOL commandDown = (event.modifierFlags & NSEventModifierFlagCommand) == NSEventModifierFlagCommand;
        if (commandDown && [[event.charactersIgnoringModifiers lowercaseString] isEqualToString:@"q"]) {
            [NSApp terminate:nil];
            return nil;
        }
        return event;
    }];
    [NSApp activateIgnoringOtherApps:YES];
    [self.store start];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [[NSFileManager defaultManager] removeItemAtPath:@"/private/tmp/local.codex.CurrencyPanel.pid" error:nil];
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        PanelLog(@"main start");
        NSApplication *app = [NSApplication sharedApplication];
        app.activationPolicy = NSApplicationActivationPolicyRegular;
        InstallAppMenu();
        AppDelegate *delegate = [AppDelegate new];
        app.delegate = delegate;
        [app finishLaunching];
        [delegate startIfNeeded];
        [app activateIgnoringOtherApps:YES];
        [app run];
        (void)delegate;
        return 0;
    }
}
