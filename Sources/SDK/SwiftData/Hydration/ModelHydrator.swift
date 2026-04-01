import Foundation

/// Mirror-based row↔object mapping for PersistentModel types.
public struct ModelHydrator {

    public init() {}

    /// Convert an object's properties to SQLiteValue array (id first, then schema-ordered).
    public func dehydrate<T: PersistentModel>(_ model: T) -> [SQLiteValue] {
        let schema = T.schema
        let mirror = Mirror(reflecting: model)
        var propsByName: [String: Any] = [:]
        for child in mirror.children {
            guard let label = child.label else { continue }
            propsByName[label] = child.value
        }

        var values: [SQLiteValue] = [.text(model.persistentModelID.id.uuidString)]
        for prop in schema.properties {
            let val = propsByName[prop.name]
            values.append(toSQLiteValue(val, type: prop.type))
        }
        return values
    }

    /// Create an object from a row. Row order: id, then schema-ordered properties.
    public func hydrate<T: PersistentModel>(_ type: T.Type, from row: [SQLiteValue]) -> T? {
        let schema = T.schema
        guard row.count >= schema.properties.count + 1 else { return nil }

        // Extract the ID.
        guard case .text(let idStr) = row[0], let uuid = UUID(uuidString: idStr) else { return nil }

        let obj = T.init()
        obj.persistentModelID = PersistentIdentifier(id: uuid)

        // Use the schema to set properties by name via key-value coding if available,
        // otherwise fall back to direct Mirror-based property setting.
        for (i, prop) in schema.properties.enumerated() {
            let sqlValue = row[i + 1]
            setProperty(on: obj, name: prop.name, value: sqlValue, type: prop.type)
        }

        return obj
    }

    // MARK: - Private

    private func toSQLiteValue(_ value: Any?, type: PropertyType) -> SQLiteValue {
        guard let value = value else { return .null }
        switch type {
        case .string:
            return .text(value as? String ?? "")
        case .int:
            return .integer(Int64(value as? Int ?? 0))
        case .int64:
            return .integer(value as? Int64 ?? 0)
        case .double:
            return .real(value as? Double ?? 0)
        case .float:
            return .real(Double(value as? Float ?? 0))
        case .bool:
            return .integer((value as? Bool ?? false) ? 1 : 0)
        case .date:
            let date = value as? Date ?? Date(timeIntervalSince1970: 0)
            return .text(ISO8601DateFormatter().string(from: date))
        case .data:
            return .blob(value as? Data ?? Data())
        case .uuid:
            return .text((value as? UUID)?.uuidString ?? "")
        }
    }

    private func setProperty(on object: AnyObject, name: String, value: SQLiteValue, type: PropertyType) {
        // Swift doesn't have native KVC for non-NSObject types.
        // We use ObjC runtime when the object is an NSObject subclass,
        // otherwise use a protocol-based approach.
        #if canImport(ObjectiveC)
        if let nsobj = object as? NSObject {
            let converted = fromSQLiteValue(value, type: type)
            nsobj.setValue(converted as? NSObject, forKey: name)
            return
        }
        #endif

        // For pure Swift classes, we need the model to conform to a setter protocol.
        if let settable = object as? PropertySettable {
            settable.setProperty(name: name, value: fromSQLiteValue(value, type: type))
        }
    }

    private func fromSQLiteValue(_ value: SQLiteValue, type: PropertyType) -> Any? {
        switch (value, type) {
        case (.null, _):
            return nil
        case (.text(let s), .string):
            return s
        case (.text(let s), .uuid):
            return UUID(uuidString: s)
        case (.text(let s), .date):
            return ISO8601DateFormatter().date(from: s)
        case (.integer(let v), .int):
            return Int(v)
        case (.integer(let v), .int64):
            return v
        case (.integer(let v), .bool):
            return v != 0
        case (.real(let v), .double):
            return v
        case (.real(let v), .float):
            return Float(v)
        case (.blob(let d), .data):
            return d
        default:
            return nil
        }
    }
}

/// Protocol for pure Swift classes to support property setting from hydration.
public protocol PropertySettable: AnyObject {
    func setProperty(name: String, value: Any?)
}
