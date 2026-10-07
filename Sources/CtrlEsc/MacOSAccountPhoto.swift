import AppKit
import OpenDirectory

enum MacOSAccountPhoto {
    static func currentUserImage() -> NSImage? {
        do {
            let node = try ODNode(session: ODSession.default(), type: ODNodeType(kODNodeTypeLocalNodes))
            let record = try node.record(
                withRecordType: kODRecordTypeUsers,
                name: NSUserName(),
                attributes: [kODAttributeTypeJPEGPhoto, kODAttributeTypePicture]
            )

            if let values = try? record.values(forAttribute: kODAttributeTypeJPEGPhoto) {
                for value in values {
                    if let data = value as? Data, let image = NSImage(data: data) {
                        return image
                    }
                }
            }

            if let values = try? record.values(forAttribute: kODAttributeTypePicture) {
                for value in values {
                    guard let path = value as? String, path.hasPrefix("/") else { continue }
                    if let image = NSImage(contentsOfFile: path) {
                        return image
                    }
                }
            }
        } catch {
            // Keep the menu usable with its generic avatar when Directory Services
            // doesn't expose an account photo.
        }

        return nil
    }
}
