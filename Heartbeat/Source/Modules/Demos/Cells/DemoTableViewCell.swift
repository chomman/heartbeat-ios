//
//  DemoTableViewCell.swift
//  Heartbeat
//
//  Created by Andrew Barba on 12/26/17.
//  Copyright © 2017 Fritz Labs, Inc. All rights reserved.
//

import UIKit

class DemoTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectionView = UIView()
        selectionView.backgroundColor = UIColor(red: 0.706, green: 0.133, blue: 0.133, alpha: 1)
        selectedBackgroundView = selectionView
    }
}
