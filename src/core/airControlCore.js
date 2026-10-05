/*
 * airControl Core
 * v4.5.0
 *
 * Public device-control API.
 *
 * React UI
 *    ↓
 * airControl Core
 *    ↓
 * Device Adapter
 *    ↓
 * Electron Transport
 */

import { CHIP_FAMILIES, detectChip, getDeviceCapabilities } from "./deviceCapabilities.js";
import { executeLinkplay, subscribeLinkplayEvents } from "./adapters/linkplayAdapter.js";

function requireDevice(device) {
  if (!device || typeof device !== "object")
    throw new Error("Device is required");

  if (!device.ip)
    throw new Error("Device IP is missing");

  return device;
}

async function execute(device, action, value) {
  requireDevice(device);

  const chip = detectChip(device);

  switch (chip) {
    case CHIP_FAMILIES.A31:
    case CHIP_FAMILIES.A97:
    case CHIP_FAMILIES.A98:
    case CHIP_FAMILIES.UNKNOWN_LINKPLAY:
      return executeLinkplay(device, action, value);

    case CHIP_FAMILIES.A33:
    case CHIP_FAMILIES.UNKNOWN_AIRCLOUD:
      /*
       * A33 adapter will be connected next.
       * Until then React keeps its existing A33 path.
       */
      throw new Error(`Core action "${action}" is not connected for ${chip} yet`);

    default:
      throw new Error(`Unsupported device family: ${chip}`);
  }
}

export const airControlCore = Object.freeze({
  capabilities(device) {
    return getDeviceCapabilities(requireDevice(device));
  },

  chip(device) {
    return detectChip(requireDevice(device));
  },

  play(device) {
    return execute(device, "play");
  },

  pause(device) {
    return execute(device, "pause");
  },

  togglePlay(device) {
    return execute(device, "togglePlay");
  },

  next(device) {
    return execute(device, "next");
  },

  previous(device) {
    return execute(device, "previous");
  },

  setVolume(device, value) {
    return execute(device, "volume", value);
  },

  setMute(device, muted) {
    return execute(device, "mute", Boolean(muted));
  },

  seek(device, seconds) {
    return execute(device, "seek", seconds);
  },

  preset(device, number) {
    return execute(device, "preset", number);
  },

  subscribe(handler) {
    /*
     * First event source: A31 persistent TCP/8899.
     * More transports will be merged here later.
     */
    return subscribeLinkplayEvents(event => {
      handler?.({
        family: "linkplay",
        transport: "tcp8899",
        ip: event.ip,
        payload: event.payload,
        raw: event
      });
    });
  }
});

export default airControlCore;
