//
//  NagiosIcingaParser.swift
//  NagBar
//
//  Created by Volen Davidov on 10/25/15.
//  Copyright © 2015 Volen Davidov. All rights reserved.
//

import Foundation

class NagiosParser: MonitoringProcessorBase, ParserInterface {
    enum HTMLFlavor {
        case nagios
        case icinga
    }

    var htmlFlavor = HTMLFlavor.nagios

    func parse(urlType: MonitoringURLType, data: Data) -> Array<MonitoringItem> {
        switch urlType {
        case .hosts:
            return self.getHostMonitoringItems(data)
        case .services:
            return self.getServiceMonitoringItems(data)
        case .hostScheduledDowntime:
            return self.getHostMonitoringItems(data)
        }
    }

    private func getHostMonitoringItems(_ data: Data) -> Array<HostMonitoringItem> {
        let document = HTMLDocument(data: data)
        let rows = document.rows()
        let statusInformationIndex = self.htmlFlavor == .icinga ? 5 : 4

        return rows.compactMap { row -> HostMonitoringItem? in
            let cells = row.directChildren(named: "td")
            guard cells.count > statusInformationIndex,
                  let hostLink = cells[0].firstAnchor(where: { href in
                      href.contains("extinfo.cgi") && href.contains("type=1")
                  }) else {
                return nil
            }

            let host = hostLink.textContent.trimmingNagBarHTMLWhitespace()
            guard !host.isEmpty else {
                return nil
            }

            let item = HostMonitoringItem()
            item.host = host
            item.status = cells[1].textContent
            item.lastCheck = cells[2].textContent
            item.duration = cells[3].textContent
            item.statusInformation = cells[statusInformationIndex].textContent
            item.itemUrl = self.getItemUrl(hostLink.attribute("href"))
            item.acknowledged = cells[0].containsImage(named: "ack.gif")
            item.downtime = cells[0].containsImage(named: "downtime.gif")
            item.monitoringInstance = self.monitoringInstance

            return item
        }
    }

    private func getServiceMonitoringItems(_ data: Data) -> Array<ServiceMonitoringItem> {
        let document = HTMLDocument(data: data)
        let rows = document.rows()
        var previousHost = ""

        return rows.compactMap { row -> ServiceMonitoringItem? in
            let cells = row.directChildren(named: "td")
            guard cells.count > 6,
                  let serviceLink = cells[1].firstAnchor(where: { href in
                      href.contains("extinfo.cgi") && href.contains("type=2")
                  }) else {
                return nil
            }

            if let hostLink = cells[0].firstAnchor(where: { href in
                href.contains("extinfo.cgi") && href.contains("type=1")
            }) {
                let host = hostLink.textContent.trimmingNagBarHTMLWhitespace()
                if !host.isEmpty {
                    previousHost = host
                }
            }

            let service = serviceLink.textContent.trimmingNagBarHTMLWhitespace()
            guard !service.isEmpty else {
                return nil
            }

            let item = ServiceMonitoringItem()
            item.host = previousHost
            item.service = service
            item.status = cells[2].textContent
            item.lastCheck = cells[3].textContent
            item.duration = cells[4].textContent
            item.attempt = cells[5].textContent
            item.statusInformation = cells[6].textContent
            item.itemUrl = self.getItemUrl(serviceLink.attribute("href"))
            item.acknowledged = cells[1].containsImage(named: "ack.gif")
            item.downtime = cells[1].containsImage(named: "downtime.gif")
            item.monitoringInstance = self.monitoringInstance

            return item
        }
    }

    private func getItemUrl(_ itemUrl: String) -> String {
        let monitoringInstanceURL = NagiosParser.stripStatusCGI(self.monitoringInstance!.url)
        return monitoringInstanceURL + itemUrl
    }

    static func stripStatusCGI(_ itemUrl: String) -> String {
        if let index = itemUrl.range(of: "status.cgi", options: .regularExpression) {
            var urlCopy = itemUrl
            urlCopy.removeSubrange(index)

            return urlCopy
        } else {
            return itemUrl
        }
    }

    func parseStartTime(_ data: Data) -> String {
        return self.getTimeElement(data, name: "start_time")
    }

    func parseEndTime(_ data: Data) -> String {
        return self.getTimeElement(data, name: "end_time")
    }

    private func getTimeElement(_ data: Data, name: String) -> String {
        let document = HTMLDocument(data: data)

        return document.root
            .descendants(named: "input")
            .first(where: { $0.attribute("name") == name })?
            .attribute("value") ?? ""
    }
}

private final class HTMLDocument {
    let root: HTMLNode

    init(data: Data) {
        let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        self.root = HTMLParser(html: html).parse()
    }

    func rows() -> [HTMLNode] {
        return self.root.descendants(named: "tr")
    }
}

private final class HTMLNode {
    let name: String
    let attributes: [String: String]
    weak var parent: HTMLNode?
    var children: [HTMLNode]
    var textFragments: [String]

    init(name: String, attributes: [String: String] = [:]) {
        self.name = name.lowercased()
        self.attributes = attributes.reduce(into: [String: String]()) { result, entry in
            result[entry.key.lowercased()] = entry.value
        }
        self.children = []
        self.textFragments = []
    }

    var textContent: String {
        let childText = self.children.map { $0.textContent }.joined()
        return self.textFragments.joined() + childText
    }

    func attribute(_ name: String) -> String {
        return self.attributes[name.lowercased()] ?? ""
    }

    func directChildren(named name: String) -> [HTMLNode] {
        return self.children.filter { $0.name == name.lowercased() }
    }

    func descendants(named name: String) -> [HTMLNode] {
        let normalizedName = name.lowercased()
        var matches = [HTMLNode]()

        for child in self.children {
            if child.name == normalizedName {
                matches.append(child)
            }
            matches.append(contentsOf: child.descendants(named: normalizedName))
        }

        return matches
    }

    func firstAnchor(where predicate: (String) -> Bool) -> HTMLNode? {
        for anchor in self.descendants(named: "a") {
            if predicate(anchor.attribute("href")) {
                return anchor
            }
        }

        return nil
    }

    func containsImage(named imageName: String) -> Bool {
        return self.descendants(named: "img").contains { image in
            image.attribute("src").contains(imageName)
        }
    }
}

private final class HTMLParser {
    private static let voidTags = Set([
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    ])

    private let html: String

    init(html: String) {
        self.html = html
    }

    func parse() -> HTMLNode {
        let root = HTMLNode(name: "document")
        var stack = [root]
        var index = self.html.startIndex

        while index < self.html.endIndex {
            guard let tagStart = self.html[index...].firstIndex(of: "<") else {
                self.appendText(String(self.html[index...]), to: stack.last)
                break
            }

            if tagStart > index {
                self.appendText(String(self.html[index..<tagStart]), to: stack.last)
            }

            guard let tagEnd = self.html[tagStart...].firstIndex(of: ">") else {
                self.appendText(String(self.html[tagStart...]), to: stack.last)
                break
            }

            let tag = String(self.html[self.html.index(after: tagStart)..<tagEnd])
            self.apply(tag: tag, stack: &stack)
            index = self.html.index(after: tagEnd)
        }

        return root
    }

    private func appendText(_ text: String, to node: HTMLNode?) {
        let decoded = HTMLParser.decodeEntities(text)
        if !decoded.isEmpty {
            node?.textFragments.append(decoded)
        }
    }

    private func apply(tag: String, stack: inout [HTMLNode]) {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty,
              !trimmedTag.hasPrefix("!"),
              !trimmedTag.hasPrefix("?") else {
            return
        }

        if trimmedTag.hasPrefix("/") {
            let tagName = HTMLParser.tagName(String(trimmedTag.dropFirst()))
            self.close(tagName: tagName, stack: &stack)
            return
        }

        let selfClosing = trimmedTag.hasSuffix("/")
        let tagName = HTMLParser.tagName(trimmedTag)
        guard !tagName.isEmpty else {
            return
        }

        let node = HTMLNode(name: tagName, attributes: HTMLParser.attributes(from: trimmedTag))
        node.parent = stack.last
        stack.last?.children.append(node)

        if !selfClosing && !HTMLParser.voidTags.contains(tagName) {
            stack.append(node)
        }
    }

    private func close(tagName: String, stack: inout [HTMLNode]) {
        guard stack.count > 1 else {
            return
        }

        while stack.count > 1 {
            let node = stack.removeLast()
            if node.name == tagName {
                return
            }
        }
    }

    private static func tagName(_ tag: String) -> String {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedTag.prefix { character in
            !character.isWhitespace && character != "/" && character != ">"
        }

        return String(name).lowercased()
    }

    private static func attributes(from tag: String) -> [String: String] {
        let pattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*("[^"]*"|'[^']*'|[^\s"'>/]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [:]
        }

        let text = tag as NSString
        let matches = regex.matches(in: tag, range: NSRange(location: 0, length: text.length))

        return matches.reduce(into: [String: String]()) { result, match in
            guard match.numberOfRanges == 3 else {
                return
            }

            let key = text.substring(with: match.range(at: 1)).lowercased()
            var value = text.substring(with: match.range(at: 2))

            if (value.hasPrefix("\"") && value.hasSuffix("\""))
                || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            result[key] = HTMLParser.decodeEntities(value)
        }
    }

    private static func decodeEntities(_ value: String) -> String {
        var decoded = value
        let namedEntities = [
            "amp": "&",
            "apos": "'",
            "gt": ">",
            "lt": "<",
            "nbsp": "\u{00A0}",
            "quot": "\"",
        ]

        for (name, replacement) in namedEntities {
            decoded = decoded.replacingOccurrences(of: "&\(name);", with: replacement)
        }

        decoded = HTMLParser.decodeNumericEntities(in: decoded, pattern: #"&#(\d+);"#, radix: 10)
        decoded = HTMLParser.decodeNumericEntities(in: decoded, pattern: #"&#x([0-9a-fA-F]+);"#, radix: 16)

        return decoded
    }

    private static func decodeNumericEntities(in value: String, pattern: String, radix: Int) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return value
        }

        let text = value as NSString
        var result = value

        for match in regex.matches(in: value, range: NSRange(location: 0, length: text.length)).reversed() {
            guard match.numberOfRanges == 2 else {
                continue
            }

            let numberText = text.substring(with: match.range(at: 1))
            guard let scalarValue = UInt32(numberText, radix: radix),
                  let scalar = UnicodeScalar(scalarValue) else {
                continue
            }

            let range = Range(match.range(at: 0), in: result)!
            result.replaceSubrange(range, with: String(Character(scalar)))
        }

        return result
    }
}

private extension String {
    func trimmingNagBarHTMLWhitespace() -> String {
        var characterSet = CharacterSet.whitespacesAndNewlines
        characterSet.insert(charactersIn: "\u{00A0}")
        return self.trimmingCharacters(in: characterSet)
    }
}
