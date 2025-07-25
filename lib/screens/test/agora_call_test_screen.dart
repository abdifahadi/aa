"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

var _native = _interopRequireDefault(require("./native.js"));

var _rng = _interopRequireDefault(require("./rng.js"));

var _stringify = require("./stringify.js");

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function v4(options, buf, offset) {
  if (_native.default.randomUUID && !buf && !options) {
    return _native.default.randomUUID();
  }

  options = options || {};

  const rnds = options.random || (options.rng || _rng.default)(); // Per 4.4, set bits for version and `clock_seq_hi_and_reserved`


  rnds[6] = rnds[6] & 0x0f | 0x40;
  rnds[8] = rnds[8] & 0x3f | 0x80; // Copy bytes to buffer, if provided

  if (buf) {
    offset = offset || 0;

    for (let i = 0; i < 16; ++i) {
      buf[offset + i] = rnds[i];
    }

    return buf;
  }

  return (0, _stringify.unsafeStringify)(rnds);
}

var _default = v4;
exports.default = _default;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               "use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.URL = exports.DNS = void 0;
exports.default = v35;

var _stringify = require("./stringify.js");

var _parse = _interopRequireDefault(require("./parse.js"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function stringToBytes(str) {
  str = unescape(encodeURIComponent(str)); // UTF8 escape

  const bytes = [];

  for (let i = 0; i < str.length; ++i) {
    bytes.push(str.charCodeAt(i));
  }

  return bytes;
}

const DNS = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';
exports.DNS = DNS;
const URL = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';
exports.URL = URL;

function v35(name, version, hashfunc) {
  function generateUUID(value, namespace, buf, offset) {
    var _namespace;

    if (typeof value === 'string') {
      value = stringToBytes(value);
    }

    if (typeof namespace === 'string') {
      namespace = (0, _parse.default)(namespace);
    }

    if (((_namespace = namespace) === null || _namespace === void 0 ? void 0 : _namespace.length) !== 16) {
      throw TypeError('Namespace must be array-like (16 iterable integer values, 0-255)');
    } // Compute hash of namespace and value, Per 4.3
    // Future: Use spread syntax when supported on all platforms, e.g. `bytes =
    // hashfunc([...namespace, ... value])`


    let bytes = new Uint8Array(16 + value.length);
    bytes.set(namespace);
    bytes.set(value, namespace.length);
    bytes = hashfunc(bytes);
    bytes[6] = bytes[6] & 0x0f | version;
    bytes[8] = bytes[8] & 0x3f | 0x80;

    if (buf) {
      offset = offset || 0;

      for (let i = 0; i < 16; ++i) {
        buf[offset + i] = bytes[i];
      }

      return buf;
    }

    return (0, _stringify.unsafeStringify)(bytes);
  } // Function#name is not settable on some platforms (#270)


  try {
    generateUUID.name = name; // eslint-disable-next-line no-empty
  } catch (err) {} // For CommonJS default export support


  generateUUID.DNS = DNS;
  generateUUID.URL = URL;
  return generateUUID;
}                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    llSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ ����� ����q�

�`�p�OĂ��ԭ�d��� �E��;`�' \\. \DISPLAY1�	� ��X  L  H  I� @   "N  �$�� ` �A��� P�Ԗ�@H 0@4��[   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito�r&192 '%l10&�s�q_DCS^Size�Div
bIs
 ed=0)�g��h���y��  D��  �ؐ�Oā `��  ��#�d��t� ����"�@�  8�@��C��`Ɍ���C�A�'�{��%��"    H  � @   "N  �$�� ` �A��� P�Ԗ�@H 0@4�^   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ ����� ����q�

�`�p�OĂ��ԭ�d��� �E��;`�' \\. \DISPLAY1�	� ��X  L  H  I� @   "N  �$�� ` �Al�� P�Ԗ�@H 0@4�``   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito�r&192 '%l10&�s�q_DCS^Size�Div
bIs
 ed=0)�g��h���y��  D��  �ؐ�Oā `��  ��#�d��t� ����"�@�  8�@��C���ƌ���C�A�'`{��%��"    H  � @   "N  �$�� ` �A0�� P�Ԗ�@H 0@4��b   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ ����� ����q�

�`�p�OĂ��ԭ�d��� �E��;`�' \\. \DISPLAY1�	� ��X  L  H  I� @   "N  �$�� ` �A�0� P�Ԗ�@H 0@4��d   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito�r&192 '%l10&�s�q_DCS^Size�Div
bIs
 ed=0)�g��h���y��  D��  �ؐ�Oā `��  ��#�d��t� ����"�@�  8�@��C��������C�A�'�y��%��"    H  � @   "N  �$�� ` �A�1� P�Ԗ�@H 0@4�8g   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ ����� ����q�

�`�p�OĂ��ԭ�d��� �E��;`�' \\. \DISPLAY1�	