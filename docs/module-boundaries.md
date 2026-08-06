# Module dependency boundaries

Framelingo modules separate public contracts from implementation selection.

- An API target (`Sources/Api`) may depend only on API products. It owns public domain values, requests, actions, and type-erased UI factories.
- An ordinary implementation target (`Sources/Impl`) may depend on its own API and other packages' API products. It must not import or depend on another package's `Impl` product.
- A product composition target chooses concrete implementations and injects API-typed dependencies. `MacApp` is the macOS product composer.
- The executable depends on its product composer; it does not assemble individual capabilities.
- Tests may import the implementation under test. Multi-implementation integration tests belong to a product-composer test target.
- Previews should use API-typed placeholder or recording factories unless they live at a product-composition boundary.

`ProjectFeature` therefore receives `ProjectFeatureComponents` containing Player, Timeline, Subtitle Editor, Shorts, and Export factories. It never imports those implementations. Concrete macOS factories are selected in `MacAppComposition`.

There is no Application umbrella or global AppState. Settings, project catalog, preparation, transcription, translation, and video export expose focused owners. The product root injects them directly, and `ProjectFeature` receives one shared `ProjectSession` plus its child component factories.

`ProjectSession` provides a SwiftUI-free API/Impl core for immutable snapshots, transactions, bounded history, interaction grouping, persistence, and project-scoped effects. `MacApp` creates one session per workspace lifetime and shares it across the composed screens.

Run the checks locally with:

```sh
ruby Scripts/audit-module-boundaries.rb --self-test
```

To register a future product root such as `MacApp` or `IOSApp`, add its exact target name to `PRODUCT_COMPOSERS` in the audit script and keep all concrete implementation selection inside that target. The allow-list is intentionally explicit; an `Impl` suffix alone never grants composition privileges.
