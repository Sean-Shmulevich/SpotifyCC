import { redirectToAuthCodeFlow, newAccessToken, getAccessToken } from './spotifyUtils/auth.js'

import { setRepeat, setShuffle } from './spotifyUtils/playerApi.js'

export const SpotifyAuth = {
  redirectToAuthCodeFlow: redirectToAuthCodeFlow,
  newAccessToken: newAccessToken,
  getAccessToken: getAccessToken
}

export const SpotifyPlayerApi = {
  setRepeat: setRepeat,
  setShuffle: setShuffle
}