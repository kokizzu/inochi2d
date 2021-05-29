/*
    Inochi2D Bone Group

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.pathdeform;
import inochi2d.core.nodes.part;
import inochi2d.core.nodes;
import inochi2d.core.dbg;
import inochi2d.math;

/**
    A node that deforms multiple nodes against a path.
*/
class PathDeform : Node {
private:
    
    // Joint Origins
    vec2[] jointOrigins;

    // Computed joint matrices
    mat3[] computedJoints;


    void recomputeJoints() {
        foreach(i; 0..joints.length) {
            float startAngle;
            float endAngle;
            size_t next = i+1;
            
            // Special Case:
            // We're at the end of the joints list
            // There's nothing to "orient" ourselves against, so
            // We'll just have a rotational value of 0
            if (next >= joints.length) {
                startAngle = atan2(
                    jointOrigins[i-1].y - jointOrigins[i].y, 
                    jointOrigins[i-1].x - jointOrigins[i].x
                );
                
                endAngle = atan2(
                    joints[i-1].y - joints[i].y, 
                    joints[i-1].x - joints[i].x
                );
            } else {

                // Get the angles between our origin positions and our
                // Current joint positions to get the difference.
                // The difference between the root angle and the current
                // angle determines how much the point and path is rotated.
                startAngle = atan2(
                    jointOrigins[i].y - jointOrigins[next].y, 
                    jointOrigins[i].x - jointOrigins[next].x
                );

                endAngle = atan2(
                    joints[i].y - joints[next].y, 
                    joints[i].x - joints[next].x
                );
            }


            // Apply our wonky math to our computed joint
            computedJoints[i] = mat3.translation(vec3(joints[i], 0)) * mat3.zrotation(startAngle-endAngle);
        }
    }

public:

    /**
        The current joint locations of the deformation
    */
    vec2[] joints;

    /**
        The bindings from joints to verticies in multiple parts

        [Drawable] = Every drawable that is affected
        [] = the entry of the joint
        size_t[] = the entry of verticies in that part that should be affected.
    */
    size_t[][][Drawable] bindings;

    /**
        Gets joint origins
    */
    vec2[] origins() {
        return jointOrigins;
    }

    /**
        Constructs a new path deform
    */
    this(vec2[] joints, Node parent = null) {
        this.setJoints(joints);
        super(parent);
    }

    /**
        Sets the joints for this path deform
    */
    void setJoints(vec2[] joints) {
        this.jointOrigins = joints.dup;
        this.joints = joints.dup;
        this.computedJoints = new mat3[joints.length];
    }

    /**
        Adds a joint with the specified offset to the end of the joints list
    */
    void addJoint(vec2 joint) {
        jointOrigins ~= jointOrigins[$-1] + joint;
        joints ~= jointOrigins[$-1];
        computedJoints.length++;
    }

    /**
        Sets the position of joint as its new origin
    */
    void setJointOriginFor(size_t index) {
        if (index >= joints.length) return;
        jointOrigins[index] = joints[index];
    }

    /**
        Updates the spline group.
    */
    override
    void update() {
        this.recomputeJoints();

        // Iterates over every part attached to this deform
        // Then iterates over every joint that should affect that part
        // Then appplies the deformation across that part's joints
        foreach(Drawable part, size_t[][] entry; bindings) {
            MeshData mesh = part.getMesh();
            
            foreach(jointEntry, vertList; entry) {
                mat3 joint = computedJoints[jointEntry];

                // Deform vertices
                foreach(i; vertList) {
                    part.vertices[i] = (joint * vec3(mesh.vertices[i], 0)).xy;
                }
            }

            part.refresh();
        }

        super.update();
    }

    
    override
    void drawOutlineOne() {
        auto trans = transform.matrix();

        if (inDbgDrawMeshOrientation) {
            inDbgLineWidth(4);
            inDbgSetBuffer([vec2(0, 0), vec2(32, 0)], [0, 1]);
            inDbgDrawLines(vec4(1, 0, 0, 0.3), trans);
            inDbgSetBuffer([vec2(0, 0), vec2(0, -32)], [0, 1]);
            inDbgDrawLines(vec4(0, 1, 0, 0.3), trans);

            foreach(i, joint; computedJoints) {
                inDbgSetBuffer(
                    [vec2(joints[i].x, joints[i].y), vec2(joints[i].x+32, joints[i].y)], [0, 1]);
                inDbgDrawLines(vec4(1, 0, 0, 0.3), trans*mat4(joint));
                inDbgSetBuffer(
                    [vec2(joints[i].x, joints[i].y), vec2(joints[i].x, joints[i].y-32)], [0, 1]);
                inDbgDrawLines(vec4(0, 1, 0, 0.3), trans*mat4(joint));
            }
            inDbgLineWidth(1);
        }
    }

    /**
        Resets the positions of joints
    */
    void resetJoints() {
        joints = jointOrigins;
        computedJoints.length = joints.length;
    }
}