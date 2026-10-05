/*
 * airControl Core — Linkplay Adapter
 * v4.5.0
 *
 * React talks in logical commands.
 * This adapter chooses the actual Linkplay transport.
 */

import { CHIP_FAMILIES, getDeviceCapabilities } from "../deviceCapabilities.js";

function bridge() {
  if (!window.airCloud) throw new Error("Electron transport bridge unavailable");
  return window.airCloud;
}

function httpCommand(action, value) {
  switch (action) {
    case "play":       return "setPlayerCmd:resume";
    case "pause":      return "setPlayerCmd:pause";
    case "togglePlay": return "setPlayerCmd:onepause";
    case "next":       return "setPlayerCmd:next";
    case "previous":   return "setPlayerCmd:prev";
    case "volume":     return `setPlayerCmd:vol:${Math.max(0, Math.min(100, Number(value) || 0))}`;
    case "mute":       return `setPlayerCmd:mute:${value ? 1 : 0}`;
    case "seek":       return `setPlayerCmd:seek:${Math.max(0, Math.round(Number(value) || 0))}`;
    case "preset":     return `MCUKeyShortClick:${Math.max(1, Math.min(10, Number(value) || 1))}`;
    default:           return null;
  }
}

function a31TcpCommand(action, value, device) {
  switch (action) {
    case "play":
      return "MCU+PLY-PLA";

    case "pause":
      return "MCU+PLY-PUS";

    case "togglePlay":
      return String(device?.track?.playState || "").toLowerCase() === "play"
        ? "MCU+PLY-PUS"
        : "MCU+PLY-PLA";

    case "next":
      return "MCU+PLY+NXT";

    case "previous":
      return "MCU+PLY+PRV";

    case "volume": {
      const n = Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
      return `MCU+VOL+${String(n).padStart(3, "0")}`;
    }

    case "mute":
      return `MCU+MUT+00${value ? 1 : 0}`;

    case "preset": {
      const n = Math.max(1, Math.min(10, Math.round(Number(value) || 1)));
      return `MCU+KEY+${String(n).padStart(3, "0")}`;
    }

    // Seek stays on the known Linkplay HTTP path for now.
    // Do not invent an MCU/8899 seek command.
    case "seek":
      return null;

    default:
      return null;
  }
}

async function linkplayHttp(device, command) {
  const b = bridge();
  if (!b.request) throw new Error("Electron HTTP transport unavailable");

  const capabilities = getDeviceCapabilities(device);

  const protocol =
    capabilities.chip === CHIP_FAMILIES.A31
      ? "http"
      : "https";

  const port = protocol === "https" ? 443 : 80;

  return b.request({
    ip: device.ip,
    instruct: command,
    apiStyle: "linkplay",
    protocol,
    port
  });
}

async function a31Tcp(device, command) {
  const b = bridge();

  if (!b.linkplayMcuRequest)
    return { ok:false, error:"A31 TCP transport unavailable" };

  return b.linkplayMcuRequest({
    ip: device.ip,
    port: 8899,
    command,
    expectReply: false,
    timeout: 700
  });
}

export async function executeLinkplay(device, action, value) {
  if (!device?.ip) throw new Error("Device IP is missing");

  const capabilities = getDeviceCapabilities(device);
  const fallback = httpCommand(action, value);

  if (!fallback)
    throw new Error(`Unsupported Linkplay action: ${action}`);

  /*
   * A31:
   * TCP/8899 first for verified fast-control commands.
   * If TCP fails, preserve the existing working HTTP path.
   */
  if (capabilities.chip === CHIP_FAMILIES.A31 && capabilities.tcp8899) {
    const tcpCommand = a31TcpCommand(action, value, device);

    if (tcpCommand) {
      try {
        const result = await a31Tcp(device, tcpCommand);

        if (result?.ok) {
          return {
            ...result,
            transport: "tcp8899",
            command: tcpCommand
          };
        }
      } catch {
        // Deliberately continue to HTTP fallback.
      }
    }
  }

  const result = await linkplayHttp(device, fallback);

  return {
    ...result,
    transport:
      capabilities.chip === CHIP_FAMILIES.A31
        ? "http"
        : "https",
    command: fallback
  };
}

export function subscribeLinkplayEvents(handler) {
  const b = bridge();

  if (!b.onLinkplayMcuEvent)
    return () => {};

  return b.onLinkplayMcuEvent(event => {
    if (!event?.ip || !event?.payload) return;
    handler?.(event);
  });
}
