# deploy-kit Delta Design

Building and publishing are separate operations. Build reads `.workflow` and writes the repository's generated `.agents` artifact. Publish reads only that artifact plus standard OpenSpec integration sources, copies them to the target, and removes the superseded downstream source layout.
