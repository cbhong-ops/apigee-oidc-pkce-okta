// PKCE: get initial code challenge - code challenge method is 'S256'
var codeChallenge = context.getVariable('oauthv2authcode.OAuthV2-GetOriginalStateAttributes.code_challenge');

// get code verifier from form params
var codeVerifier = context.getVariable('request.formparam.code_verifier');

// create a new SHA-256 object
var sha256 = crypto.getSHA256();

// update thw SHA-256 object
sha256.update(codeVerifier);

// return the SHA-256 object as a base64Url string
var hashedCodeVerifier = sha256.digest64().replace(/=+$/, '')
// replace characters according to base64url specifications
.replace(/\+/g, '-')
.replace(/\//g, '_');

// is PKCE code verified or not ? yes => true, no => false
var isPKCECodeVerified = ( hashedCodeVerifier === codeChallenge )?true:false;

// set context variable 'oidc.flow.isPKCECodeVerified'
context.setVariable('oidc.flow.isPKCECodeVerified',isPKCECodeVerified);