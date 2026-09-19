# SDK troubleshooting

| Symptom                                             | Check                                                                                                                       |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| npm returns 404                                     | npm publication is pending. Obtain the matching integration archives; do not install the repository root as an npm package. |
| Constructor rejects a key                           | Use `pk_`, not a server-side `ak_` key.                                                                                     |
| Configuration fails                                 | Check key spelling, revocation, API base URL, network and the returned error status.                                        |
| A browser request fails on one website              | Check the exact allowed origin, including scheme and development port.                                                      |
| Item is absent                                      | Check key scope, merchant ID, published menu, availability and model filters.                                               |
| Native iOS shows a poster                           | Check USDZ conversion. Native SceneKit cannot render GLB.                                                                   |
| Browser 3D works but AR does not                    | Check HTTPS, phone/browser support and the model's AR format.                                                               |
| React variables have no effect                      | Set them on `.armenus-viewer.your-class` after the default stylesheet.                                                      |
| React Native `style` does not recolor the AR button | `style` applies to the outer view; internal theming is not exposed.                                                         |
| A native model steals list scrolling                | Set `interactionEnabled` to false in scrolling rows.                                                                        |
| Hook says no client found                           | Wrap the component in `ArmenusProvider`.                                                                                    |
| A scene is blank or a request stalls                | Keep a poster fallback and handle errors. Inspect the network response before retrying.                                     |

`ArmenusError` exposes `status`, `code` and `details`. Report those fields plus the
SDK version, platform, reproduction steps and whether the error occurs with a
published item. Do not put secret keys, private account data or full authenticated
request headers in an issue.

For native apps, rebuild after adding or updating the SDK so its Swift and Kotlin
code is included. Test camera AR on a supported phone. See [errors](https://developers.armenus.app/errors) and
[formats](https://developers.armenus.app/formats) for the full reference.
