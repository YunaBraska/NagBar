//
//  FilterOptionsTabController.swift
//  NagBar
//
//  Created by Volen Davidov on 14.01.16.
//  Copyright © 2016 Volen Davidov. All rights reserved.
//

import Cocoa

class FilterOptionsTabController: NSWindowController {
    
    @IBOutlet weak var filterItemsTable: NSTableView!
    
    var filterItemWindow: FilterItemWindowController?
    var filterItemWindowFactory: () -> FilterItemWindowController = {
        FilterItemWindowController(windowNibName: "FilterItemWindow")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // refresh the table after the FilterItemWindow was closed
        Foundation.NotificationCenter.default.addObserver(self, selector: #selector(FilterOptionsTabController.refreshTable), name: NSWindow.willCloseNotification, object: filterItemWindow)
    }
    
    @objc func refreshTable() {
        self.filterItemsTable.reloadData()
    }
    
    deinit {
        Foundation.NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func segControlClicked(_ sender: NSSegmentedControl) {
        
        let selectedSegment = SegmentControl(rawValue: sender.selectedSegment)
        
        switch selectedSegment! {
        case .add:
            filterItemWindow = filterItemWindowFactory()
            filterItemWindow!.showWindow(self)
        case .delete:
            if filterItemsTable.selectedRow != -1 {
                FilterItems().removeById(filterItemsTable.selectedRow)
                filterItemsTable.reloadData()
            }
        case .edit:
            if filterItemsTable.selectedRow != -1 {
                filterItemWindow = filterItemWindowFactory()
                filterItemWindow!.filterItemKey = FilterItems.generateKey(FilterItems().getById(filterItemsTable.selectedRow).host, service: FilterItems().getById(filterItemsTable.selectedRow).service)
                filterItemWindow!.showWindow(self)
            }
        }
    }
}
