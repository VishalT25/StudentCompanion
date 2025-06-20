import coremltools as ct

# Convert using array of 1000 features
input_features = [f"feature_{i}" for i in range(1000)]

model = ct.convert(
    "StudentCompanionClassifier.mlmodel",
    inputs=[ct.TensorType(name=name, shape=(1,)) for name in input_features],
    source="tensorflow"
)
model.save("StudentCompanionClassifier.mlmodel")