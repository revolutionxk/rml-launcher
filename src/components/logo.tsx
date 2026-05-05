export default function Logo({ size = 52 }: { size?: number }) {
  return (
    <img src="/icons/logo_tilt_wrench.png" alt="RML Launcher Logo" width={size} height={size} />
  );
}
