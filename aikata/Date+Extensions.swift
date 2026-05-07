import Foundation

extension Date {
    func chatTimestampString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    func relativeTimeString() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)
        
        if let day = components.day, day > 0 {
            return "\(day)日前"
        }
        
        if let hour = components.hour, hour > 0 {
            return "\(hour)時間前"
        }
        
        if let minute = components.minute, minute > 0 {
            return "\(minute)分前"
        }
        
        return "たった今" // Less than a minute
    }

    func chatDateSeparatorString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: self)
    }
}
