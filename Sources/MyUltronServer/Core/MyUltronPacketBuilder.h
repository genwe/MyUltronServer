//
//  MyUltronPacketBuilder.h
//  MyUltronServer
//
//  C++ packet builder/decoder for the binary protocol.
//

#ifndef MyUltronPacketBuilder_h
#define MyUltronPacketBuilder_h

#import <Foundation/Foundation.h>
#include "MyUltronPacket.h"

class MyUltronPacketBuilder {
public:
    MyUltronPacketBuilder()  = default;
    ~MyUltronPacketBuilder();

    // ---- Build packets ----
    void buildPingPacket();
    void buildPongPacket();
    void buildTextPacket(NSString *text);
    void buildBinaryPacket(NSData *data);
    void buildJsonPacket(NSDictionary *dict);

    /// Returns the current packet. Caller must NOT free it.
    myultron_packet_t* getPacket();

    // ---- Decode ----
    /// Decodes raw data into the internal packet buffer.
    void decodePacket(NSData *data);

private:
    void resetPacket();
    void doBuildPacket(NSData *data, MyUltronPacketType type);

    myultron_packet_t *packet = nullptr;
};

#endif /* MyUltronPacketBuilder_h */
