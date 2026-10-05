/*
 * airControl Core — Device Capabilities
 * v4.5.0
 *
 * One place for protocol/capability decisions.
 * React UI must not choose HTTP/TCP/UPnP transports directly.
 */

export const CHIP_FAMILIES = Object.freeze({
  A31: "A31",
  A97: "A97",
  A98: "A98",
  A33: "A33",
  UNKNOWN_LINKPLAY: "UNKNOWN_LINKPLAY",
  UNKNOWN_AIRCLOUD: "UNKNOWN_AIRCLOUD"
});

export function detectChip(device = {}) {
  const hardware = String(device.hardware || device.model || "").toUpperCase();
  const project = String(device.project || "").toUpperCase();
  const type = String(device.deviceType || "").toLowerCase();

  if (hardware === "A31" || project.includes("UP2STREAM_PRO_V4"))
    return CHIP_FAMILIES.A31;

  if (
    hardware === "A97" ||
    hardware.includes("ALLWINNER-R328") ||
    project.includes("R328")
  )
    return CHIP_FAMILIES.A97;

  if (
    hardware === "A98" ||
    hardware.includes("AMLOGICA113") ||
    hardware.includes("AMLOGIC A113") ||
    project.includes("AMLOGIC")
  )
    return CHIP_FAMILIES.A98;

  if (
    hardware === "A33" ||
    type === "aircloud" ||
    project.includes("CLOUDYX") ||
    project.includes("CLOUDIX")
  )
    return CHIP_FAMILIES.A33;

  return type === "airscope"
    ? CHIP_FAMILIES.UNKNOWN_LINKPLAY
    : CHIP_FAMILIES.UNKNOWN_AIRCLOUD;
}

const BASE = Object.freeze({
  play: true,
  pause: true,
  next: true,
  previous: true,
  volume: true,
  mute: true,
  seek: true
});

export function getDeviceCapabilities(device = {}) {
  const chip = detectChip(device);

  switch (chip) {
    case CHIP_FAMILIES.A31:
      return {
        ...BASE,
        chip,

        // Hardware/project verified.
        primaryControl: "tcp8899",
        tcp8899: true,
        tcpPush: true,

        http: true,
        https: false,
        upnp: true,

        // TCP failure must preserve the known working HTTP path.
        fallbackControl: "http",

        tcpMinCommandGapMs: 200,

        presets: true,
        usb: true,
        multiroom: true,
        eq: true,

        // UART API is available through the verified PAS/RAKOIT
        // tunnel on TCP/8899. Physical UART itself is not implied.
        uartPassthrough: true,
        physicalUartVerified: false
      };

    case CHIP_FAMILIES.A97:
      return {
        ...BASE,
        chip,

        // Hardware verified transport. TCP/8899 remains unknown.
        primaryControl: "https",
        tcp8899: false,
        tcpPush: false,

        http: false,
        https: true,
        upnp: true,

        fallbackControl: "upnp",

        presets: true,
        usb: true,
        multiroom: true,

        // Keep disabled until verified on A97 hardware.
        eq: false,

        streamServicesCapability: true,
        playQueue: true
      };

    case CHIP_FAMILIES.A98:
      return {
        ...BASE,
        chip,

        primaryControl: "https",
        tcp8899: false,
        tcpPush: false,

        http: false,
        https: true,
        upnp: true,

        fallbackControl: "upnp",

        presets: true,
        usb: false,
        multiroom: true,
        eq: true,

        streamServicesCapability: true,
        playQueue: true,
        samba: true
      };

    case CHIP_FAMILIES.A33:
      return {
        ...BASE,
        chip,

        // Event-driven native architecture.
        primaryControl: "tcp1234",
        tcp1234: true,
        tcp23040: true,
        tcpPush: true,

        // gmrender is not the primary A33 control transport.
        upnpRenderer: true,
        gmrenderPrimary: false,

        presets: true,
        usb: true,
        multiroom: true,
        eq: true
      };

    case CHIP_FAMILIES.UNKNOWN_LINKPLAY:
      return {
        ...BASE,
        chip,
        primaryControl: "auto-linkplay",
        tcp8899: false,
        tcpPush: false,
        http: true,
        https: true,
        upnp: true,
        fallbackControl: "auto-linkplay"
      };

    default:
      return {
        ...BASE,
        chip,
        primaryControl: "legacy-aircloud",
        tcpPush: false
      };
  }
}

export function supports(device, capability) {
  return getDeviceCapabilities(device)[capability] === true;
}
