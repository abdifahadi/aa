"use strict";
// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
Object.defineProperty(exports, "__esModule", { value: true });
exports.OAuth2Client = exports.CertificateFormat = exports.CodeChallengeMethod = void 0;
const gaxios_1 = require("gaxios");
const querystring = require("querystring");
const stream = require("stream");
const formatEcdsa = require("ecdsa-sig-formatter");
const crypto_1 = require("../crypto/crypto");
const authclient_1 = require("./authclient");
const loginticket_1 = require("./loginticket");
var CodeChallengeMethod;
(function (CodeChallengeMethod) {
    CodeChallengeMethod["Plain"] = "plain";
    CodeChallengeMethod["S256"] = "S256";
})(CodeChallengeMethod = exports.CodeChallengeMethod || (exports.CodeChallengeMethod = {}));
var CertificateFormat;
(function (CertificateFormat) {
    CertificateFormat["PEM"] = "PEM";
    CertificateFormat["JWK"] = "JWK";
})(CertificateFormat = exports.CertificateFormat || (exports.CertificateFormat = {}));
class OAuth2Client extends authclient_1.AuthClient {
    constructor(optionsOrClientId, clientSecret, redirectUri) {
        super();
        this.certificateCache = {};
        this.certificateExpiry = null;
        this.certificateCacheFormat = CertificateFormat.PEM;
        this.refreshTokenPromises = new Map();
        const opts = optionsOrClientId && typeof optionsOrClientId === 'object'
            ? optionsOrClientId
            : { clientId: optionsOrClientId, clientSecret, redirectUri };
        this._clientId = opts.clientId;
        this._clientSecret = opts.clientSecret;
        this.redirectUri = opts.redirectUri;
        this.eagerRefreshThresholdMillis =
            opts.eagerRefreshThresholdMillis || 5 * 60 * 1000;
        this.forceRefreshOnFailure = !!opts.forceRefreshOnFailure;
    }
    /**
     * Generates URL for consent page landing.
     * @param opts Options.
     * @return URL to consent page.
     */
    generateAuthUrl(opts = {}) {
        if (opts.code_challenge_method && !opts.code_challenge) {
            throw new Error('If a code_challenge_method is provided, code_challenge must be included.');
        }
        opts.response_type = opts.response_type || 'code';
        opts.client_id = opts.client_id || this._clientId;
        opts.redirect_uri = opts.redirect_uri || this.redirectUri;
        // Allow scopes to be passed either as array or a string
        if (Array.isArray(opts.scope)) {
            opts.scope = opts.scope.join(' ');
        }
        const rootUrl = OAuth2Client.GOOGLE_OAUTH2_AUTH_BASE_URL_;
        return (rootUrl +
            '?' +
            querystring.stringify(opts));
    }
    generateCodeVerifier() {
        // To make the code compatible with browser SubtleCrypto we need to make
        // this method async.
        throw new Error('generateCodeVerifier is removed, please use generateCodeVerifierAsync instead.');
    }
    /**
     * Convenience method to automatically generate a code_verifier, and its
     * resulting SHA256. If used, this must be paired with a S256
     * code_challenge_method.
     *
     * For a full example see:
     * https://github.com/googleapis/google-auth-library-nodejs/blob/main/samples/oauth2-codeVerifier.js
     */
    async generateCodeVerifierAsync() {
        // base64 encoding uses 6 bits per character, and we want to generate128
        // characters. 6*128/8 = 96.
        const crypto = (0, crypto_1.createCrypto)();
        const randomString = crypto.randomBytesBase64(96);
        // The valid characters in the code_verifier are [A-Z]/[a-z]/[0-9]/
        // "-"/"."/"_"/"~". Base64 encoded strings are pretty close, so we're just
        // swapping out a few chars.
        const codeVerifier = randomString
            .replace(/\+/g, '~')
            .replace(/=/g, '_')
            .replace(/\//g, '-');
        // Generate the base64 encoded SHA256
        const unencodedCodeChallenge = await crypto.sha256DigestBase64(codeVerifier);
        // We need to use base64UrlEncoding instead of standard base64
        const codeChallenge = unencodedCodeChallenge
            .split('=')[0]
            .replace(/\+/g, '-')
            .replace(/\//g, '_');
        return { codeVerifier, codeChallenge };
    }
    getToken(codeOrOptions, callback) {
        const options = typeof codeOrOptions === 'string' ? { code: codeOrOptions } : codeOrOptions;
        if (callback) {
            this.getTokenAsync(options).then(r => callback(null, r.tokens, r.res), e => callback(e, null, e.response));
        }
        else {
            return this.getTokenAsync(options);
        }
    }
    async getTokenAsync(options) {
        const url = OAuth2Client.GOOGLE_OAUTH2_TOKEN_URL_;
        const values = {
            code: options.code,
            client_id: options.client_id || this._clientId,
            client_secret: this._clientSecret,
            redirect_uri: options.redirect_uri || this.redirectUri,
            grant_type: 'authorization_code',
            code_verifier: options.codeVerifier,
        };
        const res = await this.transporter.request({
            method: 'POST',
            url,
            data: querystring.stringify(values),
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        });
        const tokens = res.data;
        if (res.data && res.data.expires_in) {
            tokens.expiry_date = new Date().getTime() + res.data.expires_in * 1000;
            delete tokens.expires_in;
        }
        this.emit('tokens', tokens);
        return { tokens, res };
    }
    /**
     * Refreshes the access token.
     * @param refresh_token Existing refresh token.
     * @private
     */
    async refreshToken(refreshToken) {
        if (!refreshToken) {
            return this.refreshTokenNoCache(refreshToken);
        }
        // If a request to refresh using the same token has started,
        // return the same promise.
        if (this.refreshTokenPromises.has(refreshToken)) {
            return this.refreshTokenPromises.get(refreshToken);
        }
        const p = this.refreshTokenNoCache(refreshToken).then(r => {
            this.refreshTokenPromises.delete(refreshToken);
            return r;
        }, e => {
            this.refreshTokenPromises.delete(refreshToken);
            throw e;
        });
        this.refreshTokenPromises.set(refreshToken, p);
        return p;
    }
    async refreshTokenNoCache(refreshToken) {
        var _a;
        if (!refreshToken) {
            throw new Error('No refresh token is set.');
        }
        const url = OAuth2Client.GOOGLE_OAUTH2_TOKEN_URL_;
        const data = {
            refresh_token: refreshToken,
            client_id: this._clientId,
            client_secret: this._clientSecret,
            grant_type: 'refresh_token',
        };
        let res;
        try {
            // request for new token
            res = await this.transporter.request({
                method: 'POST',
                url,
                data: querystring.stringify(data),
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            });
        }
        catch (e) {
            if (e instanceof gaxios_1.GaxiosError &&
                e.message === 'invalid_grant' &&
                ((_a = e.response) === null || _a === void 0 ? void 0 : _a.data) &&
                /ReAuth/i.test(e.response.data.error_description)) {
                e.message = JSON.stringify(e.response.data);
            }
            throw e;
        }
        const tokens = res.data;
        // TODO: de-duplicate this code from a few spots
        if (res.data && res.data.expires_in) {
            tokens.expiry_date = new Date().getTime() + res.data.expires_in * 1000;
            delete tokens.expires_in;
        }
        this.emit('tokens', tokens);
        return { tokens, res };
    }
    refreshAccessToken(callback) {
        if (callback) {
            this.refreshAccessTokenAsync().then(r => callback(null, r.credentials, r.res), callback);
        }
        else {
            return this.refreshAccessTokenAsync();
        }
    }
    async refreshAccessTokenAsync() {
        const r = await this.refreshToken(this.credentials.refresh_token);
        const tokens = r.tokens;
        tokens.refresh_token = this.credentials.refresh_token;
        this.credentials = tokens;
        return { credentials: this.credentials, res: r.res };
    }
    getAccessToken(callback) {
        if (callback) {
            this.getAccessTokenAsync().then(r => callback(null, r.token, r.res), callback);
        }
        else {
            return this.getAccessTokenAsync();
        }
    }
    async getAccessTokenAsync() {
        const shouldRefresh = !this.credentials.access_token || this.isTokenExpiring();
        if (shouldRefresh) {
            if (!this.credentials.refresh_token) {
                if (this.refreshHandler) {
                    const refreshedAccessToken = await this.processAndValidateRefreshHandler();
                    if (refreshedAccessToken === null || refreshedAccessToken === void 0 ? void 0 : refreshedAccessToken.access_token) {
                        this.setCredentials(refreshedAccessToken);
                        return { token: this.credentials.access_token };
                    }
                }
                else {
                    throw new Error('No refresh token or refresh handler callback is set.');
                }
            }
            const r = await this.refreshAccessTokenAsync();
            if (!r.credentials || (r.credentials && !r.credentials.access_token)) {
                throw new Error('Could not refresh access token.');
            }
            return { token: r.credentials.access_token, res: r.res };
        }
        else {
            return { token: this.credentials.access_token };
        }
    }
    /**
     * The main authentication interface.  It takes an optional url which when
     * present is the endpoint being accessed, and returns a Promise which
     * resolves with authorization header fields.
     *
     * In OAuth2Client, the result has the form:
     * { Authorization: 'Bearer <access_token_value>' }
     * @param url The optional url being authorized
     */
    async getRequestHeaders(url) {
        const headers = (await this.getRequestMetadataAsync(url)).headers;
        return headers;
    }
    async getRequestMetadataAsync(
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    url) {
        const thisCreds = this.credentials;
        if (!thisCreds.access_token &&
            !thisCreds.refresh_token &&
            !this.apiKey &&
            !this.refreshHandler) {
            throw new Error('No access, refresh token, API key or refresh handler callback is set.');
        }
        if (thisCreds.access_token && !this.isTokenExpiring()) {
            thisCreds.token_type = thisCreds.token_type || 'Bearer';
            const headers = {
                Authorization: thisCreds.token_type + ' ' + thisCreds.access_token,
            };
            return { headers: this.addSharedMetadataHeaders(headers) };
        }
        // If refreshHandler exists, call processAndValidateRefreshHandler().
        if (this.refreshHandler) {
            const refreshedAccessToken = await this.processAndValidateRefreshHandler();
            if (refreshedAccessToken === null || refreshedAccessToken === void 0 ? void 0 : refreshedAccessToken.access_token) {
                this.setCredentials(refreshedAccessToken);
                const headers = {
                    Authorization: 'Bearer ' + this.credentials.access_token,
                };
                return { headers: this.addSharedMetadataHeaders(headers) };
            }
        }
        if (this.apiKey) {
            return { headers: { 'X-Goog-Api-Key': this.apiKey } };
        }
        let r = null;
        let tokens = null;
        try {
            r = await this.refreshToken(thisCreds.refresh_token);
            tokens = r.tokens;
        }
        catch (err) {
            const e = err;
            if (e.response &&
                (e.response.status === 403 || e.response.status === 404)) {
                e.message = `Could not refresh access token: ${e.message}`;
            }
            throw e;
        }
        const credentials = this.credentials;
        credentials.token_type = credentials.token_type || 'Bearer';
        tokens.refresh_token = credentials.refresh_token;
        this.credentials = tokens;
        const headers = {
            Authorization: credentials.token_type + ' ' + tokens.access_token,
        };
        return { headers: this.addSharedMetadataHeaders(headers), res: r.res };
    }
    /**
     * Generates an URL to revoke the given token.
     * @param token The existing token to be revoked.
     */
    static getRevokeTokenUrl(token) {
        const parameters = querystring.stringify({ token });
        return `${OAuth2Client.GOOGLE_OAUTH2_REVOKE_URL_}?${parameters}`;
    }
    revokeToken(token, callback) {
        const opts = {
            url: OAuth2Client.getRevokeTokenUrl(token),
            method: 'POST',
        };
        if (callback) {
            this.transporter
                .request(opts)
                .then(r => callback(null, r), callback);
        }
        else {
            return this.transporter.request(opts);
        }
    }
    revokeCredentials(callback) {
        if (callback) {
            this.revokeCredentialsAsync().then(res => callback(null, res), callback);
        }
        else {
            return this.revokeCredentialsAsync();
        }
    }
    async revokeCredentialsAsync() {
        const token = this.credentials.access_token;
        this.credentials = {};
        if (token) {
            return this.revokeToken(token);
        }
        else {
            throw new Error('No acce