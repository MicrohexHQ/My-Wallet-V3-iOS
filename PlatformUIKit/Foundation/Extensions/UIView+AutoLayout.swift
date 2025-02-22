//
//  UIView+AutoLayout.swift
//  Blockchain
//
//  Created by Daniel Huri on 30/06/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import UIKit

public enum LayoutForm {
    case horizontal
    case vertical
    case center
    case size
}

extension UIView {
    
    public func layoutToSuperview(_ layoutForms: LayoutForm..., offset: CGFloat = 0) {
        guard let superview = superview else {
            print("\(#function): superview is nil")
            return
        }
        translatesAutoresizingMaskIntoConstraints = false
        for form in layoutForms {
            switch form {
            case .horizontal:
                NSLayoutConstraint.activate([
                    leftAnchor.constraint(equalTo: superview.leftAnchor,
                                          constant: offset),
                    rightAnchor.constraint(equalTo: superview.rightAnchor,
                                           constant: -offset)
                    ])
            case .vertical:
                NSLayoutConstraint.activate([
                    topAnchor.constraint(equalTo: superview.topAnchor, constant: offset),
                    bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -offset)
                    ])
            case .center:
                NSLayoutConstraint.activate([
                    centerXAnchor.constraint(equalTo: superview.centerXAnchor, constant: offset),
                    centerYAnchor.constraint(equalTo: superview.centerYAnchor, constant: offset)
                    ])
            case .size:
                NSLayoutConstraint.activate([
                    heightAnchor.constraint(equalTo: superview.heightAnchor, constant: offset),
                    widthAnchor.constraint(equalTo: superview.widthAnchor, constant: offset)
                    ])
            }
        }
    }
    
    /// Layout the size of the view to a given size
    public func layoutSize(to size: CGSize) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height)
            ])
    }
    
    public func fillSuperview() {
        layoutToSuperview(.horizontal, .vertical)
    }
}
