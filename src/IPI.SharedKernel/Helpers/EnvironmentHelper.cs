namespace IPI.SharedKernel.Helpers
{
    public static class EnvironmentHelper
    {
        public static bool IsDevelopment(string environmentName) => environmentName == "Development";
    }
}
