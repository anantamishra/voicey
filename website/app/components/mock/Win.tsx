import type { ReactNode } from "react";

/** A small macOS-style window used by the demo scenes. Decorative only. */
export default function Win({
  title,
  className = "",
  children,
}: {
  title: string;
  className?: string;
  children: ReactNode;
}) {
  return (
    <div className={`v-win ${className}`.trim()}>
      <div className="v-bar">
        <span className="v-lights">
          <i />
          <i />
          <i />
        </span>
        <b>{title}</b>
      </div>
      {children}
    </div>
  );
}
