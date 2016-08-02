//
//  ViewController.swift
//  SGCalendar
//
//  Created by 周永 on 16/7/19.
//  Copyright © 2016年 shuige. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let calendarView = SGCalendar(delegate: self)
        view.addSubview(calendarView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension ViewController: SGCalendarDelegate {
    
    func calendarDidSelectDate(calendar: SGCalendar, date: NSDate) {
        
        print("date = \(date)")
        
    }
    
}

