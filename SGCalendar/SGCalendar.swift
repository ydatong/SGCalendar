//
//  SGCalendar.swift
//  SGCalendar
//
//  Created by 周永 on 16/7/19.
//  Copyright © 2016年 shuige. All rights reserved.
//

import UIKit

let ScreenSize = UIScreen.mainScreen().bounds.size
let RowHeight = UIScreen.mainScreen().bounds.size.width/7
let RowWidth = UIScreen.mainScreen().bounds.size.width/7
let ItemSize = CGSizeMake(UIScreen.mainScreen().bounds.size.width/7, UIScreen.mainScreen().bounds.size.width/7)
let ItemMargin: CGFloat = 5.0
let GregorianCalendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
let SolarCalendar = NSCalendar(identifier: NSCalendarIdentifierChinese)
let TimeIntervalPerDay: NSTimeInterval = 24*60*60

@objc protocol SGCalendarDelegate {
    optional func calendarDidSelectDate(calendar: SGCalendar, date:NSDate);
}

class SGCalendar: UIView {
    
    var weekView = UIView(frame: CGRectMake(0,RowHeight,ScreenSize.width,RowHeight))
    var monthView = UIButton(frame: CGRectMake(ScreenSize.width/4,0,ScreenSize.width/2,RowHeight))
    let dayView = DayView(frame: CGRectMake(0,RowHeight*2,ScreenSize.width,RowHeight*6))
    var delegate: SGCalendarDelegate?
    let weekdays = ["日","一","二","三","四","五","六"]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    
    init() {
        super.init(frame: CGRectZero)
        setupSubviews()
    }
    
    
    init(delegate: SGCalendarDelegate?) {
        super.init(frame: CGRectZero)
        self.delegate = delegate
        setupSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
  
    func setupSubviews() {
        
        self.frame = CGRectMake(0, 20, ScreenSize.width, RowHeight*8)
        monthView.setTitle(yearAndMonthString(NSDate()), forState: .Normal)
        monthView.setTitleColor(UIColor.blackColor(), forState: .Normal)
        addSubview(monthView)
        dayView.date = NSDate()
        dayView.dateDidChaged = { (date: NSDate) in
            self.monthView.setTitle(self.yearAndMonthString(date), forState: .Normal)
        }
        dayView.didSelectDate = { (date: NSDate) in
            guard let delegate = self.delegate else {
                return
            }
            delegate.calendarDidSelectDate!(self, date: date)
        }
        addSubview(dayView)
        configWeekView()
        addSubview(weekView)
    }
    
    func configWeekView() {
        
        for i in 0...weekdays.count-1 {
            let weekday = UILabel(frame: CGRect(x: CGFloat(i)*RowWidth,y: 0,width: RowWidth,height: RowHeight))
            weekday.text = weekdays[i]
            weekday.textAlignment = .Center
            weekView.addSubview(weekday)
        }
    }
}

//date calculate
extension SGCalendar {
    
    func yearAndMonthString(date: NSDate) ->String {
        return "\(date.dateComponents().year)/\(date.dateComponents().month)"
    }
}


class DayView: UIView {
    
    var dayView = UICollectionView(frame: CGRectZero, collectionViewLayout: UICollectionViewFlowLayout())
    var daysInCurrentMonth: [NSDate] = []
    var dateRange: NSRange!
    let chineseDays = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十","十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十", "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
    let chineseMonth = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月","九月", "十月", "冬月", "腊月"]
    
    var dateDidChaged: ((date: NSDate)->Void)?
    var didSelectDate: ((date: NSDate)->Void)?
    var animatiing = false //是否正在记性动画
    var animationContainerView = UIView(frame: CGRectZero)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        dayView.frame = bounds
        animationContainerView.frame = bounds
    }
    
    //getter & setter
    var date: NSDate = NSDate(){
        
        willSet(newValue){
            dateRange = newValue.rangeOfCurrentMonth()
            //生成当前月份所有的日期
            configDaysInMonth(newValue)
            dayView.reloadData()
        }
    }
    
    //setup
    func setupSubviews() {
        
        addSubview(animationContainerView)
        dayView.backgroundColor = UIColor.whiteColor()
        dayView.registerClass(CalendarCell.self, forCellWithReuseIdentifier: "cell")
        dayView.delegate = self
        dayView.dataSource = self
        let layout = dayView.collectionViewLayout as! UICollectionViewFlowLayout
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.itemSize = ItemSize
        animationContainerView.addSubview(dayView)
        addPanGestureToDayView()
    }
    
    func addPanGestureToDayView() {
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(self.panOnDayView(_:)))
        dayView.addGestureRecognizer(swipe)
    }
    
    func panOnDayView(pan: UIPanGestureRecognizer) {
        
        if pan.state == .Ended && !animatiing{
            addAnimationToDayView(pan)
        }
    }
    
    let pageCurlDuration = 1.0
    let kPageCurlKey = "pageCurl"
    let kPageUnCurlKey = "pageUnCurl"
    

    func addAnimationToDayView(pan: UIPanGestureRecognizer) {
        let translation = pan.translationInView(dayView)
        //创建一个转场动画
        let transitioin = CATransition()
        transitioin.duration = pageCurlDuration
        transitioin.timingFunction = CAMediaTimingFunction(name: "default")
        //在动画结束之后保证状态不被移除(这个两个属性得同时设置)
        transitioin.fillMode = kCAFillModeForwards
        transitioin.removedOnCompletion = false
        //设置代理，在动画开始和结束的代理方法中可以处理一些事情
        transitioin.delegate = self
        if translation.y < 0 {//上
            if translation.x > 0 {//右上角翻页
                animationContainerView.layer.transform = CATransform3DMakeRotation(CGFloat(M_PI), 0, 1, 0)
                dayView.layer.transform = CATransform3DMakeRotation(CGFloat(-M_PI), 0, 1, 0)
            }
            transitioin.type = kPageCurlKey
            transitioin.subtype = kCATransitionFromBottom
            transitioin.setValue("next", forKey: "month")
        }else{//下
            if translation.x < 0 {//左下角翻页
                animationContainerView.layer.transform = CATransform3DMakeRotation(CGFloat(M_PI), 0, 1, 0)
                dayView.layer.transform = CATransform3DMakeRotation(CGFloat(-M_PI), 0, 1, 0)
            }
            transitioin.type = kPageUnCurlKey
            transitioin.subtype = kCATransitionFromTop
            transitioin.setValue("pre", forKey: "month")
        }
        
        dayView.layer.addAnimation(transitioin, forKey: "pageCurl")
    }
}

//animation handle
extension DayView {
    
    override func animationDidStart(anim: CAAnimation) {
        animatiing = true
        let components = GregorianCalendar?.components([.Year,.Month,.Day], fromDate: date)
        if anim.valueForKey("month") as! String == "next" {
            components?.month += 1
        }else if anim.valueForKey("month") as! String == "pre"{
            components?.month -= 1
        }
        date = (GregorianCalendar?.dateFromComponents(components!))!
        dateDidChaged!(date: date)
    }
    
    override func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        if flag {
           animatiing = false
           animationContainerView.layer.transform = CATransform3DIdentity
           dayView.layer.transform = CATransform3DIdentity
           dayView.layer.removeAnimationForKey("pageCurl")
        }
    }
}


//date calculate
extension DayView {
    //阴历转阳历
    func lunarToSolar(date: NSDate) -> NSDateComponents {
        let components = SolarCalendar?.components([.Year,.Month,.Day], fromDate: date)
        return components!
    }
    
    func dateAtIndexPath(indexPath: NSIndexPath) ->NSDate{
        let day = indexPath.item - dateRange.location
        return daysInCurrentMonth[day]
    }
    
    func configDaysInMonth(date: NSDate) {
        //得到当前月的第一天
        let firstDay = date.firstDateOfCurrentMonth()
        daysInCurrentMonth = []
        for i in 0...dateRange.length-1 {
            let iDate = NSDate(timeInterval: NSTimeInterval(i)*TimeIntervalPerDay, sinceDate: firstDay)
            daysInCurrentMonth.append(iDate)
        }
    }
}

extension DayView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 6*7
    }
    
    func collectionView(collectionView: UICollectionView,
                        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath) as! CalendarCell
        cell.backgroundColor = UIColor.whiteColor()
        if indexPath.item >= dateRange.location && (indexPath.item - dateRange.location) < dateRange.length {
            cell.lunarLabel.text = "\(indexPath.item - dateRange.location + 1)"
            let dateAtIndex = dateAtIndexPath(indexPath)
            let chineseDay = chineseDays[lunarToSolar(dateAtIndex).day-1]
            if chineseDay == "初一"{//如果是每个月的第一天
                cell.solarLabel.text = chineseMonth[lunarToSolar(dateAtIndex).month-1]
                cell.solarLabel.textColor = UIColor.redColor()
            }else{
                cell.solarLabel.text = chineseDay
                cell.solarLabel.textColor = UIColor.greenColor()
            }
            
            if lunarToSolar(dateAtIndex) == lunarToSolar(NSDate()) {//如果是当前日
                cell.layer.cornerRadius = cell.frame.size.width/2
                cell.layer.masksToBounds = true
                cell.backgroundColor = UIColor.grayColor()
            }
        }else{
            cell.lunarLabel.text = ""
            cell.solarLabel.text = ""
            cell.backgroundColor = UIColor.whiteColor()
        }
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        if indexPath.item >= dateRange.location && (indexPath.item - dateRange.location) < dateRange.length {
            if didSelectDate != nil {
                didSelectDate!(date: dateAtIndexPath(indexPath))
            }
        }
    }
}

class CalendarCell: UICollectionViewCell {
    
    let lunarLabel = UILabel()
    let solarLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubviews() {
        
        lunarLabel.textAlignment = .Center
        lunarLabel.font = UIFont.systemFontOfSize(15)
        solarLabel.textAlignment = .Center
        solarLabel.font = UIFont.systemFontOfSize(10)
        addSubview(lunarLabel)
        addSubview(solarLabel)
    }
    
    override func layoutSubviews() {
        
        let heightPercent: CGFloat = 0.7
        lunarLabel.frame = CGRectMake(0, 0, frame.size.width, frame.size.height*heightPercent)
        solarLabel.frame = CGRectMake(0, frame.size.height*(heightPercent-0.1), frame.size.width, frame.size.height*(1-heightPercent))
    }
    
}


extension NSDate {
    
    //location 代表第一天是星期几
    //lenght 代表总共有多少天
    func rangeOfCurrentMonth() ->NSRange {
        return NSMakeRange(firstDayOfCurrentMonth(), daysCountOfCurrentMonth())
    }
    
    //当前月第一天
    func firstDateOfCurrentMonth() ->NSDate{
        let calendar = NSCalendar(identifier:NSCalendarIdentifierGregorian )
        let currentDateComponents = calendar!.components([.Year,.Month], fromDate: self)
        let startOfMonth = calendar!.dateFromComponents(currentDateComponents)
        let date = startOfMonth?.dateByAddingTimeInterval(8*60*60)
        return date!
    }
    
    //当前月的第一天是星期几
    func firstDayOfCurrentMonth() -> Int {
        let calendar = NSCalendar.currentCalendar()
        let components  = calendar.components(.Weekday, fromDate: firstDateOfCurrentMonth())
        return components.weekday-1
    }
    
    //当前月总共有多少天
    func daysCountOfCurrentMonth() -> Int {
        let calendar = NSCalendar(identifier:NSCalendarIdentifierGregorian )
        return (calendar?.rangeOfUnit(.Day, inUnit: .Month, forDate: self).length)!
    }
    
    func dateComponents() -> NSDateComponents {
        let calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
        let components = calendar?.components([.Year,.Month,.Day], fromDate: self)
        return components!
    }
}


































