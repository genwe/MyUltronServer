//
//  MyUltronPacket.h
//  MyUltronServer
//
//  Packet protocol definitions.
//  Uses usbmux-compatible binary packet format for interoperability.
//

#ifndef MyUltronPacket_h
#define MyUltronPacket_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - Packet Types

enum MyUltronPacketType {
    // Heartbeat
    MyUltronPacketTypePing          = 1010,
    MyUltronPacketTypePong          = 1020,

    // Data messages
    MyUltronPacketTypeTextMessage   = 1110,
    MyUltronPacketTypeBinaryMessage = 1120,
    MyUltronPacketTypeJsonMessage   = 1130,
};

typedef enum MyUltronPacketType MyUltronPacketType;

// MARK: - Packet Structures

typedef struct myultron_packet_header {
    int32_t length;       // Total packet length (header + payload)
    int32_t version;      // Protocol version
    int32_t packetType;   // MyUltronPacketType
    int32_t tag;          // Packet tag for request/response matching
} myultron_packet_header_t;

typedef struct myultron_packet {
    myultron_packet_header_t header;
    uint8_t payload[];    // Flexible array member (C99) — payload data
} myultron_packet_t;

// Convenience: header size in bytes
#define MYULTRON_PACKET_HEADER_SIZE   sizeof(myultron_packet_header_t)
#define MYULTRON_PACKET_LENGTH_BYTES  4

#ifdef __cplusplus
}
#endif

#endif /* MyUltronPacket_h */
