//
//  AssetEntity+CoreDataClass.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 12.03.2024.
//
//

import Foundation
import CoreData

@objc(AssetEntity)
public class AssetEntity: NSManagedObject {
    @NSManaged public var currencyName: String?
    @NSManaged public var currencySymbol: String?
    @NSManaged public var id: UUID?
    @NSManaged public var quantity: Int64
}
