//
//  AckMode.swift
//  StompSocket
//
//  Created by Kien Nguyen on 17/08/2022.
//

import Foundation

public enum AckMode: String {
    case clientIndividual = "client-individual"
    case client
    case auto
}
