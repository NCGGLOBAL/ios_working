

#import "DateUtils.h"


@implementation NSDate(DateUtils)

- (NSString *)dateToString:(NSString *)format{
	NSString *dateFmt = format;
	if (dateFmt == nil ||  [dateFmt isEqualToString:@""]== YES)
		dateFmt = @"yyyyMMddHHmmss";
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:dateFmt];
	
	NSString *stringFromDate = [dateFormatter stringFromDate:self];
    
#if !__has_feature(objc_arc)
	[dateFormatter release];
#endif

	return stringFromDate;
}

- (NSString *)dateToString:(NSString *)format localeIdentifier:(NSString *)localeIdentifier{
	NSString *dateFmt = format;
	if (dateFmt == nil ||  [dateFmt isEqualToString:@""]== YES)
		dateFmt = @"yyyyMMddHHmmss";
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:dateFmt];
    
	if (localeIdentifier && [localeIdentifier isEqualToString:@""]==NO) {
#if !__has_feature(objc_arc)
		[dateFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:localeIdentifier] autorelease]];
#else
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:localeIdentifier]];
#endif
	}
	
	
	NSString *stringFromDate = [dateFormatter stringFromDate:self];
    
#if !__has_feature(objc_arc)
	[dateFormatter release];
#endif
	
	return stringFromDate;
}


- (NSInteger)year{
	unsigned unitFlags = NSCalendarUnitYear;
    
#if !__has_feature(objc_arc)
	NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
#endif
    
	NSDateComponents *comps = [gregorian components:unitFlags fromDate:self];
	
	return [comps year];
}


- (NSInteger)month{
	unsigned unitFlags = NSCalendarUnitMonth;
    
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
#endif
    
	NSDateComponents *comps = [gregorian components:unitFlags fromDate:self];
	
	return [comps month];
}


- (NSInteger)day{
	unsigned unitFlags = NSCalendarUnitDay;
    
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
#endif

    NSDateComponents *comps = [gregorian components:unitFlags fromDate:self];
	
	return [comps day];
}


- (NSInteger)hour{
	unsigned unitFlags = NSCalendarUnitHour;
    
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
#endif
    
	NSDateComponents *comps = [gregorian components:unitFlags fromDate:self];
	
	if ([comps hour] == 12 || [comps hour] == 24){
		return 12;
	} else {
		div_t divHour = div([comps hour],  12);
		return divHour.rem;
	}
}


- (NSInteger)hour24{
	unsigned unitFlags = NSCalendarUnitHour;
    
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
#endif
    
	NSDateComponents *comps = [gregorian components:unitFlags fromDate:self];
	
	return [comps hour];
}


- (NSInteger)minute{
	unsigned unitFlags = NSCalendarUnitMinute;
    
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
#endif
    
    NSDateComponents *comps = [gregorian components:unitFlags fromDate:self];
	
	return [comps minute];
}


- (NSInteger)quarter{
	unsigned unitFlags = NSCalendarUnitQuarter;
    
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
#endif

    NSDateComponents *comps = [gregorian components:unitFlags fromDate:self];
	
	return [comps quarter];
}


- (NSInteger)second{
	unsigned unitFlags = NSCalendarUnitSecond;
    
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
#endif

    NSDateComponents *comps = [gregorian components:unitFlags fromDate:self];
	
	return [comps second];
}


- (NSDate *)addYear:(NSInteger)years{
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    NSDateComponents *offsetComponents = [[[NSDateComponents alloc] init] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *offsetComponents = [[NSDateComponents alloc] init];
#endif
    
	[offsetComponents setYear:years];
	return [gregorian dateByAddingComponents:offsetComponents toDate:self options:0];
}


- (NSDate *)addMonth:(NSInteger)months{
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    NSDateComponents *offsetComponents = [[[NSDateComponents alloc] init] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *offsetComponents = [[NSDateComponents alloc] init];
#endif

    [offsetComponents setMonth:months];
	return [gregorian dateByAddingComponents:offsetComponents toDate:self options:0];
}


- (NSDate *)addDay:(NSInteger)days{
	return [self dateByAddingTimeInterval:86400 * days];
}


- (NSDate *)addHour:(NSInteger)hour {
    return [self dateByAddingTimeInterval:3600 * hour];
}


- (NSDate *)addMinute:(NSInteger)minute {
    return [self dateByAddingTimeInterval:60 * minute];
}


- (NSDate *)FirstDayOfMonth{
	NSInteger day = [self day];
	return [self addDay:(-1 * (day -1))];
}


- (NSDate *)LastDayOfMonth{
	return [[[self FirstDayOfMonth] addMonth:1]addDay:-1];
	
}


- (NSInteger)dayOfWeek{
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
#endif
    
	NSDateComponents *weekdayComps = [gregorian components:NSCalendarUnitWeekday fromDate:self];
	return [weekdayComps weekday];
}


- (NSDate *)setDateYear:(NSInteger)year month:(NSInteger)month day:(NSInteger)day{
	return [[[[self addYear:(year-[self year])] addMonth:(month-[self month])]FirstDayOfMonth] addDay:(day - 1)];
}


- (BOOL)isEarlierThan:(NSDate *)date{
	return [date isEqualToDate:[self earlierDate:date]];
}


- (BOOL)isLaterThan:(NSDate *)date{
	return [date isEqualToDate:[self laterDate:date]];
}


- (NSDate *)dateWithHour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second {
#if !__has_feature(objc_arc)
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
#else
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
#endif
    
    NSDateComponents *components = [gregorian components: NSCalendarUnitYear|
                                    NSCalendarUnitMonth|
                                    NSCalendarUnitDay
                                               fromDate:self];
    [components setHour:hour];
    [components setMinute:minute];
    [components setSecond:second];
    NSDate *newDate = [gregorian dateFromComponents:components];
    return newDate;
}


@end




