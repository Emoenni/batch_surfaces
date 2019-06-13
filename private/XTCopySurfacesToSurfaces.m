%combine two surface objects into a single surface object for Imaris version <9.0

function XTCopySurfacesToSurfaces(surface_source,surface_target,ids)
    try
        surface_data = surface_source.GetSurfacesList(ids);
        surface_target.AddSurfacesList(surface_data.mVertices,surface_data.mNumberOfVerticesPerSurface,surface_data.mTriangles,surface_data.mNumberOfTrianglesPerSurface,surface_data.mNormals,surface_data.mTimeIndexPerSurface);
    catch
        warning('Use Imaris Version 8 for using this function. Imaris 9 already has the function CopySurfacesToSurfaces')
    end
end

